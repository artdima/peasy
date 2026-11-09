# Releasing an update

Peasy updates itself with [Sparkle](https://sparkle-project.org). The app reads `appcast.xml` from the `main` branch, and the archives live in GitHub Releases.

Sparkle's tools come with the package Xcode downloads:

```sh
SPARKLE=$(echo ~/Library/Developer/Xcode/DerivedData/Peasy-*/SourcePackages/artifacts/sparkle/Sparkle/bin)
```

## Once

1. Run `$SPARKLE/generate_keys`. The private key goes to your login Keychain, the public one is printed. Put it into `SUPublicEDKey` in `Peasy/Info.plist`.
2. Back up the private key with `$SPARKLE/generate_keys -x sparkle-private-key` and keep the file out of the repo. Without it no installed copy will accept an update.

## Every release

1. Raise `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`. Sparkle compares the build number, so it has to grow every time.
2. Product → Archive, then Distribute App → Direct Distribution. Wait for notarization and export `Peasy.app`.
3. Zip it with `ditto`, which keeps the framework's symlinks, into an otherwise empty `release` folder:

   ```sh
   mkdir -p release && ditto -c -k --keepParent Peasy.app release/Peasy-0.2.0.zip
   ```

   Release notes go next to it as `release/Peasy-0.2.0.md`.
4. Add the release to the feed:

   ```sh
   $SPARKLE/generate_appcast --embed-release-notes \
     --download-url-prefix https://github.com/artdima/peasy/releases/download/v0.2.0/ \
     -o appcast.xml release/
   ```

5. Publish the GitHub release `v0.2.0` with the zip, then push `appcast.xml` to `main`.

Peasy 0.1.0 has no Sparkle inside, so its users have to install the first version with updates by hand.
