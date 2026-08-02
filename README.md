# Clever Compress

A Flutter application that creates smaller photo copies without silently
destroying the capture date used by Android and iOS photo galleries.

## Current milestone

The repository now contains a working product shell and the first native image
compression engine:

- Multi-photo/video selection with Android lost-selection recovery.
- A quality slider (20–95%) and 100%, 75%, or 50% resolution presets.
- A draggable, live before/after preview for the first selected image.
- Sequential batch state, per-item progress, failures, and output-size results.
- Android JPEG compression in Kotlin with EXIF/XMP tag copying, optional GPS
  removal, `MediaStore.DATE_TAKEN`, pending-file publication, and post-write
  capture-date verification.
- iOS JPEG compression in Swift/ImageIO with recognized metadata copying,
  optional GPS removal, `PHAssetCreationRequest.creationDate`, original output
  filename, and post-write capture-date verification.
- Flutter analyzer and domain/widget tests.

Video jobs currently fail with an explicit "next engine milestone" result; they
are not reported as successfully compressed. Android Media3 Transformer and iOS
AVFoundation export are the planned video backends.

## The platform truth about “same directory”

There is no filesystem directory for an item in the iOS Photos library. Apps
publish a new `PHAsset`; Photos decides its physical storage. The app can keep
the filename, capture date, location, and library chronology, but cannot place a
file beside the original at a path that iOS does not expose.

On Android 10+, Scoped Storage likewise requires publishing through MediaStore.
The current picker intentionally grants selected-media access without broad
library permission, but returns a private readable copy rather than a dependable
original folder identifier. Therefore this milestone saves Android output to
`Pictures/Clever Compress/`. A later optional “use original folder” mode can use
a custom MediaStore picker/folder grant where the device permits it; the safe
cross-platform contract is “same gallery, original date and modified filename,”
not “same physical directory.”

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
