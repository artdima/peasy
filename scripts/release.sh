#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

profile=${NOTARY_PROFILE:-peasy}

fail() {
    echo "error: $*" >&2
    exit 1
}

setting() {
    awk -F ' = ' -v key="$1" '$1 ~ ("^ *" key "$") { print $2; exit }' <<<"$settings"
}

notarize() {
    local result status
    result=$(xcrun notarytool submit "$1" --keychain-profile "$profile" --wait --output-format json)
    status=$(plutil -extract status raw -o - - <<<"$result")
    if [ "$status" != "Accepted" ]; then
        xcrun notarytool log "$(plutil -extract id raw -o - - <<<"$result")" --keychain-profile "$profile" >&2 || true
        fail "notarization of $(basename "$1") ended with $status"
    fi
}

[ -z "$(git status --porcelain)" ] || fail "commit your changes first"
[ "$(git rev-parse HEAD)" = "$(git rev-parse '@{u}')" ] || fail "push main first"

settings=$(xcodebuild -project Peasy.xcodeproj -scheme Peasy -configuration Release -showBuildSettings 2>/dev/null)
version=$(setting MARKETING_VERSION)
build=$(setting CURRENT_PROJECT_VERSION)
build_dir=$(setting BUILD_DIR)
sparkle="${build_dir%/Build/Products}/SourcePackages/artifacts/sparkle/Sparkle/bin"
notes="docs/releases/$version.md"

[ -f "$notes" ] || fail "write the release notes in $notes"
if grep -q "<sparkle:version>$build</sparkle:version>" appcast.xml; then
    fail "build $build is already in appcast.xml, raise CURRENT_PROJECT_VERSION"
fi
xcrun notarytool history --keychain-profile "$profile" >/dev/null 2>&1 ||
    fail "save the notarization credentials: xcrun notarytool store-credentials $profile --apple-id <email> --team-id 8Q6S7RTHBY"
command -v create-dmg >/dev/null || fail "install create-dmg: brew install create-dmg"

echo "Archiving Peasy $version ($build)…"
work="build/$version"
rm -rf "$work"
xcodebuild -project Peasy.xcodeproj -scheme Peasy -configuration Release \
    -archivePath "$work/Peasy.xcarchive" -allowProvisioningUpdates -quiet archive
xcodebuild -exportArchive -archivePath "$work/Peasy.xcarchive" -exportPath "$work/export" \
    -exportOptionsPlist scripts/ExportOptions.plist -allowProvisioningUpdates -quiet
app="$work/export/Peasy.app"

echo "Notarizing…"
ditto -c -k --keepParent "$app" "$work/Peasy.zip"
notarize "$work/Peasy.zip"
xcrun stapler staple -q "$app"

echo "Building the disk image…"
identity=$(codesign -dvv "$app" 2>&1 | awk -F '=' '$1 == "Authority" && !found { print $2; found = 1 }')
[ -n "$identity" ] || fail "can't read the identity $app is signed with"
mkdir "$work/dmg"
ditto "$app" "$work/dmg/Peasy.app"
tiffutil -cathidpicheck scripts/dmg/background.png scripts/dmg/background@2x.png -out "$work/background.tiff"
dmg="$work/Peasy-$version.dmg"
create-dmg --volname Peasy --background "$work/background.tiff" \
    --window-size 660 400 --icon-size 128 --text-size 12 \
    --icon Peasy.app 170 194 --hide-extension Peasy.app --app-drop-link 490 194 \
    --codesign "$identity" --hdiutil-quiet "$dmg" "$work/dmg" >"$work/create-dmg.log" ||
    fail "create-dmg failed, see $work/create-dmg.log"
notarize "$dmg"
xcrun stapler staple -q "$dmg"

echo "Updating appcast.xml…"
[ -x "$sparkle/generate_appcast" ] || fail "Sparkle tools are missing in $sparkle"
out="release/$version"
rm -rf "$out"
mkdir -p "$out"
ditto -c -k --keepParent "$app" "$out/Peasy-$version.zip"
cp "$notes" "$out/Peasy-$version.md"
"$sparkle/generate_appcast" --embed-release-notes \
    --download-url-prefix "https://github.com/artdima/peasy/releases/download/v$version/" \
    -o appcast.xml "$out"
cp "$dmg" "$out/"

cat <<NEXT

Peasy $version ($build) is in appcast.xml. Publish the archive first, then the feed:
  gh release create v$version "$out/Peasy-$version.dmg" "$out/Peasy-$version.zip" --title "Peasy $version" --notes-file "$notes"
  git commit -m "Publish $version in the appcast" appcast.xml && git push
NEXT
