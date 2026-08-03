# Clever Compress

A Flutter application that creates smaller photo copies without silently
destroying the capture date used by Android and iOS photo galleries.

## Current milestone

The repository now contains a working product shell and the first native image
compression engine:

- Multi-photo/video selection with Android lost-selection recovery.
- Independent photo and video recipes: each media type has its own quality
  slider (20–95%) and 100%, 75%, or 50% resolution presets in a mixed batch.
- A draggable, live before/after preview for the first selected image.
- Sequential batch state, per-item progress, failures, and output-size results.
- Android image compression in Kotlin with EXIF/XMP tag copying, optional GPS
  removal, `MediaStore.DATE_TAKEN`, same-folder MediaStore publication, and
  post-write capture-date verification.
- iOS image compression in Swift/ImageIO with recognized metadata copying,
  optional GPS removal, `PHAssetCreationRequest.creationDate`, output filename,
  and post-write capture-date verification.
- Android video export through Media3 Transformer and iOS video export through
  AVFoundation, with per-video quality/frame-size settings and output date
  verification where the source container and platform expose it.
- Flutter analyzer and domain/widget tests.

See [docs/MEDIA_SUPPORT.md](docs/MEDIA_SUPPORT.md) for container, codec, and
metadata limits. Device decoder support remains the final authority for a
specific input file.

## The platform truth about “same directory”

There is no filesystem directory for an item in the iOS Photos library. Apps
publish a new `PHAsset`; Photos decides its physical storage. The app can keep
the filename, capture date, location, and library chronology, but cannot place a
file beside the original at a path that iOS does not expose.

On Android 10+, Scoped Storage requires publishing through MediaStore. The
Android picker retains the selected local MediaStore relative path and publishes
the output into that same folder. Cloud-only providers do not expose a local
directory; those items return a clear error rather than silently saving to a
different location.

## Architecture

```text
lib/
  core/                         theme and formatting
  features/compress/
    domain/                     immutable media/settings/result models
    data/                       picker, live preview, native channel adapter
    presentation/               controller, screen, reusable widgets
android/.../MainActivity.kt     Kotlin MediaStore + ExifInterface engine
ios/Runner/AppDelegate.swift   Swift PhotoKit + ImageIO engine
```

Flutter owns UI and batch orchestration. Native code owns final encoding,
metadata handling, gallery database dates, and publication. The Flutter preview
is disposable and deliberately does not claim metadata preservation; only the
native output is verified.

## Run locally

Install Flutter stable, Android Studio with JDK 17/Android SDK, and full Xcode on
macOS. Then run:

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

For the configured development Mac, use the one-command daily workflow in
[DEVELOPMENT.md](DEVELOPMENT.md): `./dev android`, `./dev ios`, `./dev check`,
and `./dev build`.

This workspace uses Flutter 3.44.8 / Dart 3.12.2. The current host has Android
SDK 37, Android Studio's bundled JDK, Xcode 26.6, and CocoaPods 1.17.0. Flutter
analysis and tests pass, and both the Android debug APK and iOS Simulator app
compile successfully. Real-device metadata fixtures remain required before a
production release.

## Required device verification

Automated metadata fixtures should cover JPEG/HEIC inputs with:

1. `DateTimeOriginal`, subsecond, and timezone offset.
2. GPS kept and GPS intentionally removed.
3. Rotated orientation and resized pixel dimensions.
4. Large images under memory pressure.
5. Duplicate output filenames.
6. Gallery ordering after reboot/reindex.

The product should only show a “date verified” success badge when the native
engine has read the output back and matched its capture-date fingerprint. No
mobile API can guarantee preservation of every private maker note for every
camera/file format; the app’s strict guarantee is the normalized capture date,
gallery chronology, filename intent, and supported EXIF/TIFF/GPS fields.
Compress. Optimize. Protect metadata.
