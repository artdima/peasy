# Releasing an update

Peasy updates itself with [Sparkle](https://sparkle-project.org). The app reads `appcast.xml` from the `main` branch, and the archives live in GitHub Releases.

Sparkle's tools come with the package Xcode downloads:

```sh
SPARKLE=$(echo ~/Library/Developer/Xcode/DerivedData/Peasy-*/SourcePackages/artifacts/sparkle/Sparkle/bin)
```

## Once

1. Run `$SPARKLE/generate_keys`. The private key goes to your login Keychain, the public one is printed. Put it into `SUPublicEDKey` in `Peasy/Info.plist`.
2. Back up the private key with `$SPARKLE/generate_keys -x ~/Documents/sparkle-private-key` and keep the file out of the repo. Without it no installed copy will accept an update.

## Every release

1. Raise `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`. Sparkle compares the build number, so it has to grow every time. Write the notes in `docs/releases/<version>.md`, commit and push.
2. Product → Archive, then Distribute App → Direct Distribution. Wait for notarization and export `Peasy.app`, for example into `build/`.
3. Run `scripts/release.sh build/Peasy.app`. It zips the app with `ditto` into `release/<version>/` and adds it to `appcast.xml`.
4. Publish the GitHub release `v<version>` with the zip, then push `appcast.xml` to `main`. The script prints both commands.

Peasy 0.1.0 has no Sparkle inside, so its users have to install the first version with updates by hand.
