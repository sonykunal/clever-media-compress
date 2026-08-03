# Clever Media Compress — AI Agent Rules

These rules apply to every change. Treat them as acceptance criteria.

## Core requirements

- Implement every user-facing feature for Android and iOS in the same change.
  Do not leave stubs, placeholders, or platform-specific “coming later” paths.
- Keep the user-visible contract equivalent across platforms: terminology,
  defaults, controls, progress, success, errors, cancellation, naming, and
  fallbacks. If exact parity is impossible, explain the OS limitation, get
  approval for the closest alternative, and document it.
- Before editing, inspect the affected Dart, Kotlin, Swift, channel, storage,
  state, and test paths. Preserve existing behavior and keep the diff scoped.
- Never overwrite or delete originals. Never silently change capture dates or
  claim metadata was preserved without verifying it.

## Architecture

- Keep the Flutter UI + platform service + Kotlin/Swift native engine design.
- Put shared models, policy, validation, and presentation logic in Dart feature
  layers. Keep widgets declarative and native details behind services.
- Prefer typed models and small testable helpers. Centralize platform-channel
  names, arguments, result fields, and error semantics; keep Android and iOS in
  sync.
- Keep asynchronous media work cancellable where possible, off the UI thread,
  and release codecs, bitmaps, files, observers, and temporary data on every
  exit path. Bound batch concurrency and avoid multiple full-resolution copies.
- Centralize UI strings for localization and maintain accessibility, including
  semantic labels, contrast, scalable text, touch targets, and reduced motion.

## Media, metadata, and storage

- Detect the real MIME/container when possible, not only the filename extension.
  Preserve the original filename base and add the configured suffix before the
  actual output extension (for example, `photo_compressed.png`).
- Extract metadata before encoding. Preserve supported EXIF/XMP/GPS, creation
  time, orientation, color, and container metadata according to privacy choices.
- Write capture time to both the output and gallery/Photos record when supported.
  Verify it before showing “Date verified”; otherwise show “Needs review” with
  the native reason.
- On Android, use Scoped Storage and the selected MediaStore asset context for
  same-folder output; never silently use another folder. On iOS, use PhotoKit,
  preserve creation dates and album relationships where authorized, and never
  claim an inaccessible physical path was preserved.
- Feature-detect cloud-only, RAW, animated, HDR, spatial, slow-motion, and
  proprietary formats. Preserve them safely or return a precise unsupported
  error; never flatten or discard special content silently.
- Use unique temporary files, clean them up on success and failure, and never
  modify the selected original.

## App size and performance

- App size is a first-class acceptance criterion. Always choose the smallest
  viable implementation. Do not add packages, codecs, SDKs, assets, fonts,
  native libraries, or architectures unless necessary and size-justified.
- Prefer system frameworks and existing dependencies. Before adding a
  dependency, check its maintenance, license, minimum OS, transitive size,
  native architectures, and overlap with existing capabilities.
- Avoid bundled software codecs when system/hardware codecs work. If one is
  unavoidable, document its APK/IPA size impact, supported ABIs, and why it is
  required.
- Keep release shrinking/resource optimization enabled. Exclude debug logging,
  test fixtures, sample assets, unused fonts/icons, symbols, and architectures
  from release artifacts. Prefer Android App Bundles with ABI/resource splits.
- For dependency, codec, asset, or native-engine changes, compare the smallest
  relevant release APK/AAB and iOS archive before and after. Investigate
  material growth, identify the contributor, reduce it where possible, and
  document any approved trade-off. Do not save size by removing required
  formats, metadata, accessibility, or platform parity.

## UX, permissions, and privacy

- Keep the same information hierarchy, selection flow, batch order, preview
  meaning, defaults, validation, progress, and result language on both platforms.
- Follow platform picker and permission conventions. Request the minimum access
  only when needed; prefer system pickers and scoped grants.
- Show the failing filename and actionable native reason, not only a failure
  count. Preserve user metadata/location choices consistently.
- Do not upload media/metadata, add analytics, or introduce network access
  without explicit approval. Never log media, private paths, GPS, or metadata.

## Verification and completion

- Add or update shared UI/logic tests and isolated native tests where useful.
  Normally run formatting, Flutter analysis/tests, Android build, and iOS build.
- For media/storage changes, test as applicable: JPEG with EXIF/GPS, PNG,
  HEIC/HEIF, MP4, HEVC/MOV, rotated media, no-location media, duplicate names,
  cancellation, denied/limited permission, cloud-only media, low storage, and
  mixed batches. Verify filename, real container, destination, capture date,
  orientation, playback/audio, size reduction, and cleanup.
- Update relevant documentation, especially `docs/MEDIA_SUPPORT.md`, when
  behavior, formats, dependencies, permissions, or platform limits change.
- If the user says not to run commands, do not run them; list the exact
  unverified commands instead. Final reports must state changes, verification,
  remaining device/codec limits, and how to test. Never claim universal codec or
  metadata support.
