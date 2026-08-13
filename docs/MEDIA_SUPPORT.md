# Media format policy

The app accepts media through the operating-system picker. Actual decoding is
limited by the codecs installed on the Android device or supported by the iOS
version.

## Images

- JPEG/JPG: encoded back to JPEG with the original extension.
- PNG: encoded back to lossless PNG with transparency preserved. The quality
  slider does not make PNG lossy; use resolution reduction to reduce PNG size.
- WebP: encoded back to WebP on Android and on iOS devices whose ImageIO encoder
  advertises WebP output support.
- HEIC/HEIF: preserved as HEIC on supported iOS devices. Android and unsupported
  iOS encoders normalize the output to JPEG.
- BMP, TIFF, AVIF and other static raster inputs: accepted when the device can
  decode them and normalized to JPEG when no matching encoder is available.
- Animated GIF/WebP and camera RAW files are device-dependent and are not
  guaranteed. The app must never claim universal codec support.

Embedded EXIF/XMP/GPS is copied where the destination container supports it.
The gallery capture date is also carried separately and verified after publish.
Capture metadata and source location preservation are always enabled product
guarantees rather than user-configurable switches. Location is copied only when
the source contains supported GPS/location metadata.

## Videos

Common MP4, MOV, M4V, 3GP, 3G2, MKV, WebM, AVI, MPEG/MPG, TS/MTS/M2TS, VOB,
WMV and FLV inputs are recognized. A file can be transcoded only when the device
has a decoder for its internal video/audio codecs.

- Video thumbnails are generated natively into small temporary JPEG cache files:
  Android uses `MediaMetadataRetriever`, and iOS uses `AVAssetImageGenerator`.
- Selecting a video in the batch shows that thumbnail in the same draggable,
  zoomable original/estimated comparison used for photos. The synchronized
  center divider, pinch/pan controls and inline zoom controls operate on one
  aligned frame; estimated output size and visual softness update with the video
  recipe without covering the frame with quality, frame or container badges.
  The app does not transcode a hidden video preview before submit, because that
  would increase battery, heat and temporary storage for multi-item batches.
- Android uses Jetpack Media3 Transformer with hardware codecs.
- iOS uses AVAssetExportSession with a compatible system export preset.
- Output is standardized to MP4/H.264/AAC when supported. iOS falls back to MOV
  only when its selected export preset cannot write MP4.
- The original filename base is retained: `clip.mov` becomes
  `clip_compressed.mp4`.
- Android writes the MP4 capture timestamp and gallery `DATE_TAKEN`, then checks
  both. iOS transfers AVFoundation metadata, sets the Photos creation date, and
  checks both.

HDR, Dolby Vision, spatial video, slow motion and proprietary camera metadata
may be flattened or reduced by the system transcoder. Unsupported tracks are
reported with their real native error instead of a generic batch failure.

## Output location

Android publishes into the selected item's MediaStore `RELATIVE_PATH`. Cloud-only
items have no local directory and cannot satisfy same-folder output.

On Android 13+, the app asks for visual-media access only to read the selected
item's MediaStore folder and capture date. Choose **Allow all photos and videos**
when same-folder output is required. The system picker still performs selection;
the app does not scan media outside the user's permission choice.

The Android build pins `targetSdk` 36 so Android 16 devices show the current
Photos and videos permission flow instead of the legacy compatibility warning.

The app requests full Photos and videos access on startup and before opening the
picker. Android does not let apps force this setting; when a user chooses
limited access or denies the prompt, the app shows an in-app action that opens
its system permission screen.

On Android 13+, media selection uses the system Photo Picker gallery UI so the
flow feels like a native photo attachment grid. The picker is limited to local
media because cloud-only items do not have a device directory where a same-folder
output can be created. Older Android versions, or devices without that picker
activity, fall back to the system document picker.

For local Gallery/Camera items, Android resolution tries the direct MediaStore
columns, a verified Photo Picker row ID, the Photo Picker's supported local data
column, the backing MediaStore document URI, and then an unambiguous local
MediaStore match by filename and size. Some OEM pickers, including Samsung
versions, expose a synthetic numeric filename derived from the MediaStore row
ID; the app resolves that ID, verifies the byte size, and restores the real
original filename before compression. A filename-only match is accepted only
when every matching local item points to the same folder.

For MP4 output date verification, Android checks `MediaMetadataRetriever` first
and then reads the MP4 movie-header creation timestamp directly. Source videos
without gallery or embedded creation metadata can use common camera filename
patterns such as `20260803_122921.mp4` as a final local-time fallback.

iOS Photos assets do not expose physical filesystem directories. Outputs are
published to Photos using PhotoKit with the preserved creation date. The native
picker also records user-created album identifiers, and the compressed copy is
added to every still-available source album. Smart albums and inaccessible
physical paths cannot be recreated by third-party apps. For videos, iOS
preserves existing AVFoundation creation metadata and also falls back to camera
filename patterns such as `20260803_122921.mp4` when no embedded date is
available.

## Share-sheet compression intake

- Android registers `ACTION_SEND` and `ACTION_SEND_MULTIPLE` for `image/*` and
  `video/*`. **Clever Compress** opens directly with the shared media selected.
  The app still verifies the underlying MediaStore record before offering
  same-folder output or storage reclaim.
- iOS includes a small native Share Extension named **Compress with Clever**.
  It copies the shared representations into an App Group inbox without decoding
  or changing them. Apple does not permit a standard Share Extension to launch
  its containing app, so the extension clearly asks the user to open Clever
  Compress. The app consumes the pending batch on launch or resume.
- Share-sheet files can come from cloud or document providers. Compression is
  available after the provider supplies a readable local representation, but
  same-folder publishing and Safe Storage Reclaim are shown only when a verified
  local gallery identity is available.
- iOS device signing must enable the App Group
  `group.com.clevermedia.cleverMediaCompress` for both the Runner and
  ShareExtension App IDs. The checked-in entitlements use that identifier.

## Safe Storage Reclaim

Safe Storage Reclaim is offered only after the compressed copy was successfully
published and its capture date was verified. Failed or **Needs review** items
are excluded. Originals are never replaced or overwritten during compression.

- Android 11 and newer uses `MediaStore.createTrashRequest`, so Android shows
  the exact originals and requires native user confirmation before moving them
  to Trash. On Android 10 and older, the platform has no recoverable shared
  media Trash, so the reclaim card is not offered and originals are never
  permanently deleted as a fallback.
- iOS uses `PHAssetChangeRequest.deleteAssets`. Photos displays its native
  confirmation and moves accepted assets to **Recently Deleted**, where the
  user can restore them.
- The displayed reclaimed size is the sum of the selected original file sizes;
  actual immediately available storage can differ because Trash/Recently
  Deleted retains recoverable media until the OS or user empties it.

Both features use platform frameworks already shipped with the OS. No new
Flutter package, software codec, font, or bundled native library is included.

## Post-compression flow

When a batch finishes, the active selection is cleared and the app opens a
full-screen **Success Portal** with saved, date-verified, Needs review, and
failed counts. The portal temporarily retains only the verified native asset
references needed for Safe Storage Reclaim.

The portal is rendered directly from the completed batch state rather than
being pushed after the home screen rebuilds. Its background appears on the next
Flutter frame, while portal content uses a short reduced-motion-aware entrance;
the empty home screen is never shown between processing and completion.

- If recoverable originals are eligible, the portal offers **Keep originals** or
  **Move originals to Trash**. The latter opens the native Android Trash or iOS Photos
  confirmation. Cancelling that system confirmation keeps the portal open
  and preserves every original.
- If nothing is safely reclaimable, the portal explains why and offers **Done**
  (or **Return and try again** when the entire batch failed).
- Leaving the portal discards the temporary reclaim references and reveals the
  already-reset home screen. The portal never
  deletes originals automatically.

### Release size audit (2026-08-13)

- Android split release APKs: 14,314,685 bytes (armeabi-v7a), 17,065,899
  bytes (arm64-v8a), and 18,458,186 bytes (x86_64). Compared with the baseline,
  the largest increase was 33,468 bytes; arm64 and x86_64 increased by only 700
  bytes.
- The unsigned iOS release app is reported by Flutter as 17.5 MB versus the
  17.3 MB baseline. The native Share Extension executable is 168,272 bytes and
  the Runner executable grew by 67,592 bytes; `Flutter.framework` and
  `App.framework` did not grow.
