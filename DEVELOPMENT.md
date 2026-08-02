# Daily development guide

The Android and iOS toolchains are already installed. After restarting the
MacBook, open Terminal and move to the project:

```sh
cd /Users/apple/Documents/ks-work/clever-media-compress
```

## Run the application

For Android:

```sh
./dev android
```

This starts the `clever_android` Pixel emulator when necessary, waits for it to
finish booting, installs the current app, and keeps Flutter connected.

For iOS:

```sh
./dev ios
```

This starts the most recently selected iPhone Simulator, waits for it to boot,
installs the current app, and keeps Flutter connected.

## See code changes

Keep the `./dev android` or `./dev ios` terminal running while editing files.
Use these keys in that terminal:

- `r` — hot reload normal Dart and UI changes while preserving the current page.
- `R` — hot restart when state or app initialization needs to run again.
- `q` — stop the running application.

Changes to Kotlin, Swift, permissions, native dependencies, or `pubspec.yaml`
cannot use hot reload. Press `q`, then run `./dev android` or `./dev ios` again.

## Verify changes before considering them complete

```sh
./dev check
```

This verifies formatting, performs static analysis, and runs all tests. To also
compile both native targets:

```sh
./dev build
```

Useful diagnostics:

```sh
./dev devices
./dev doctor
```

If Terminal ever reports that Flutter is unavailable, reload its configuration:

```sh
source ~/.zshrc
```
