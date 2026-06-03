fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios prepare_appstore_localizations

```sh
[bundle exec] fastlane ios prepare_appstore_localizations
```

Generate fastlane deliver metadata/screenshots from Beacon localized App Store assets

### ios validate_appstore_localizations

```sh
[bundle exec] fastlane ios validate_appstore_localizations
```

Validate generated fastlane deliver folders before talking to App Store Connect

### ios upload_appstore_localizations

```sh
[bundle exec] fastlane ios upload_appstore_localizations
```

Upload localized metadata and screenshots to the editable App Store version

### ios upload_appstore_screenshots

```sh
[bundle exec] fastlane ios upload_appstore_screenshots
```

Upload only localized screenshots to the editable App Store version

### ios submit_appstore_version

```sh
[bundle exec] fastlane ios submit_appstore_version
```

Submit the prepared App Store version after metadata/screenshots have been uploaded and a build is selected

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
