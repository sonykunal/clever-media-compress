# Clever Media Compress — AI Agent Rules

Apply these rules to every change. Treat them as acceptance criteria.

## Scope and parity

- Implement user-facing features for Android and iOS together. Keep the same
  user-visible terminology, defaults, flow, progress, results, errors,
  cancellation, naming, and fallbacks. Never leave a platform stub.
- Before editing, inspect affected Dart, Kotlin, Swift, channel, storage, state,
  and test paths. Preserve working behavior and keep the diff focused.
- Support the declared device matrix: Android brands/OEMs, iPhone models, OS
  versions, screen sizes, hardware tiers, and system settings. Use stable public
  APIs, API guards, responsive layouts, and capability detection; avoid hidden
  device requirements. Test representative low-, mid-, and high-end devices.
- If an OS, OEM, hardware, or codec prevents exact parity, explain it, get
  approval for the closest safe fallback, and document the limitation.

## Architecture and UX

- Keep the Flutter UI + platform service + Kotlin/Swift native engine design.
  Put shared models, policy, validation, and presentation in Dart feature
  layers; keep widgets declarative and native details behind services.
- Use typed models and small testable helpers. Keep channel names, arguments,
  result fields, and error semantics centralized and identical on both platforms.
- Keep media work off the UI thread, cancellable where possible, bounded in
  memory/concurrency, and cleaned up on every exit path. Release codecs,
  bitmaps, files, observers, and temporary data.
- Optimize for zero avoidable friction: keep screens responsive, transitions
  predictable, controls clear, and every action immediate or visibly progressing.
  Prevent jank, freezes, duplicate taps, lost selections, and surprising
  navigation. Preserve state where practical; make cancellation and retry safe.
- Give concise, actionable feedback for slow, denied, failed, or partial work;
  show the failing filename and native reason, not only a count. Centralize
  strings and maintain accessibility (labels, contrast, scalable text, targets,
  and reduced motion).

## Media, metadata, and storage

- Detect the real MIME/container where possible, not only the extension. Keep
  the original filename base and put the configured suffix before the real
  output extension, such as `photo_compressed.png`.
- Extract metadata before encoding. Preserve supported EXIF/XMP/GPS, creation
  time, orientation, color, and container metadata according to privacy choices.
  Write capture time to the output and gallery/Photos record where supported;
  verify it before “Date verified,” otherwise show “Needs review” with the reason.
- Android: use Scoped Storage and the selected MediaStore context for same-folder
  output. iOS: use PhotoKit and preserve creation dates/album relationships
  where authorized. Never claim an inaccessible physical path was preserved.
- Feature-detect cloud-only, RAW, animated, HDR, spatial, slow-motion, and
  proprietary formats. Preserve them safely or return a precise unsupported
  error; never flatten or discard special content silently.
- Never modify, replace, or delete originals. Use unique temporary files and
  remove them on both success and failure.

## Size, performance, permissions, and privacy

- Choose the smallest viable implementation. Prefer system frameworks and
  existing dependencies. Before adding a package, codec, SDK, asset, font,
  native library, or architecture, check necessity, maintenance, license,
  minimum OS, transitive size, ABIs, and overlap with existing capabilities.
- Avoid bundled codecs when system/hardware codecs work. Keep release shrinking
  and resource optimization enabled; exclude debug code/logging, test fixtures,
  sample assets, unused fonts/icons, symbols, and architectures. Prefer App
  Bundles with ABI/resource splits.
- For dependency, codec, asset, or native-engine changes, compare the smallest
  relevant release APK/AAB and iOS archive before/after. Investigate material
  growth, reduce it where possible, and document approved trade-offs. Never
  reduce size by removing required formats, metadata, accessibility, or parity.
- Request minimum permissions only when needed; prefer system pickers and scoped
  grants. Do not upload media/metadata, add analytics/network access, or log
  media, private paths, GPS, or metadata without explicit approval.

## Verification and handoff

- Add/update shared UI and logic tests plus isolated native tests where useful.
  Normally run formatting, Flutter analysis/tests, Android build, and iOS build.
- For media/storage changes, test applicable formats and cases: JPEG EXIF/GPS,
  PNG, HEIC/HEIF, MP4, HEVC/MOV, rotated/no-location media, duplicate names,
  cancellation, denied/limited permission, cloud-only media, low storage, and
  mixed batches. Verify filename, real container, destination, capture date,
  orientation, playback/audio, size reduction, and cleanup.
- Update relevant docs, especially `docs/MEDIA_SUPPORT.md`, when behavior,
  formats, dependencies, permissions, or platform limits change. If commands
  are disallowed, do not run them; list the exact unverified commands instead.
  Final reports must state changes, verification, limitations, and how to test.
