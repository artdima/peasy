# Releasing an update

Peasy updates itself with [Sparkle](https://sparkle-project.org). The app reads `appcast.xml` from the `main` branch, and the archives live in GitHub Releases.

Sparkle's tools come with the package Xcode downloads:

```sh
SPARKLE=$(echo ~/Library/Developer/Xcode/DerivedData/Peasy-*/SourcePackages/artifacts/sparkle/Sparkle/bin)
```

## Once

1. Run `$SPARKLE/generate_keys`. The private key goes to your login Keychain, the public one is printed. Put it into `SUPublicEDKey` in `Peasy/Info.plist`.
2. Back up the private key with `$SPARKLE/generate_keys -x ~/Documents/sparkle-private-key` and keep the file out of the repo. Without it no installed copy will accept an update.
3. Save the notarization credentials in the Keychain. The password is an app-specific one from [account.apple.com](https://account.apple.com):

   ```sh
   xcrun notarytool store-credentials peasy --apple-id <email> --team-id 8Q6S7RTHBY
   ```

   Another profile name goes to the script as `NOTARY_PROFILE`.
4. Install [create-dmg](https://github.com/create-dmg/create-dmg) with `brew install create-dmg`. It lays out the disk image window through Finder, so on the first run macOS asks to let Terminal control Finder: allow it.

## Every release

1. Raise `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`. Sparkle compares the build number, so it has to grow every time. Write the notes in `docs/releases/<version>.md`, commit and push.
2. Run `scripts/release.sh`. It archives Peasy, exports it with Developer ID, notarizes and staples it, zips it into `release/<version>/` and adds it to `appcast.xml`. Next to the zip it puts a signed and notarized disk image for people who download Peasy by hand.
3. Publish the GitHub release `v<version>` with the disk image and the zip, then push `appcast.xml` to `main`. The script prints both commands.

The disk image window shows `scripts/dmg/background.png` and `background@2x.png`, 660×400 and 1320×800. The script joins them into one TIFF, so a new background needs both sizes. Peasy sits at (170, 194), Applications at (490, 194).

Peasy 0.1.0 has no Sparkle inside, so its users have to install the first version with updates by hand.
