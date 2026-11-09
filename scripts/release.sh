#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "usage: scripts/release.sh path/to/Peasy.app" >&2
    exit 64
fi
app="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
cd "$(dirname "$0")/.."

fail() {
    echo "error: $*" >&2
    exit 1
}

info="$app/Contents/Info.plist"
[ -f "$info" ] || fail "$1 is not an app"
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$info")
build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$info")
notes="docs/releases/$version.md"
sparkle=$(ls -d ~/Library/Developer/Xcode/DerivedData/Peasy-*/SourcePackages/artifacts/sparkle/Sparkle/bin 2>/dev/null | head -n 1 || true)

[ -f "$notes" ] || fail "write the release notes in $notes"
[ -n "$sparkle" ] || fail "open Peasy.xcodeproj in Xcode so it downloads Sparkle"
if grep -q "<sparkle:version>$build</sparkle:version>" appcast.xml; then
    fail "build $build is already in appcast.xml, raise CURRENT_PROJECT_VERSION"
fi
xcrun stapler validate "$app" >/dev/null || fail "$app is not notarized"

out="release/$version"
rm -rf "$out"
mkdir -p "$out"
ditto -c -k --keepParent "$app" "$out/Peasy-$version.zip"
cp "$notes" "$out/Peasy-$version.md"
"$sparkle/generate_appcast" --embed-release-notes \
    --download-url-prefix "https://github.com/artdima/peasy/releases/download/v$version/" \
    -o appcast.xml "$out"

cat <<NEXT

Peasy $version ($build) is in appcast.xml. Publish the archive first, then the feed:
  gh release create v$version "$out/Peasy-$version.zip" --title "Peasy $version" --notes-file "$notes"
  git commit -m "Publish $version in the appcast" appcast.xml && git push
NEXT
