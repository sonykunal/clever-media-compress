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

## Videos

Common MP4, MOV, M4V, 3GP, 3G2, MKV, WebM, AVI, MPEG/MPG, TS/MTS/M2TS, VOB,
WMV and FLV inputs are recognized. A file can be transcoded only when the device
has a decoder for its internal video/audio codecs.

- Video thumbnails are generated natively into small temporary JPEG cache files:
  Android uses `MediaMetadataRetriever`, and iOS uses `AVAssetImageGenerator`.
- Selecting a video in the batch shows that thumbnail as a lightweight preview
  frame plus estimated output size, quality, frame scale and MP4 output format.
  The preview frame uses an estimated visual softness/overlay that changes with
  the video recipe so users can see settings react before export.
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
flow feels like a native photo attachment grid. Older Android versions, or
devices without that picker activity, fall back to the system document picker.

For local Gallery/Camera items, Android resolution tries the direct picker URI,
the backing MediaStore document URI, and then an unambiguous local MediaStore
match by filename and size. A filename-only match is accepted only when every
matching local item points to the same folder.

For MP4 output date verification, Android checks `MediaMetadataRetriever` first
and then reads the MP4 movie-header creation timestamp directly. Source videos
without gallery or embedded creation metadata can use common camera filename
patterns such as `20260803_122921.mp4` as a final local-time fallback.

iOS Photos assets do not expose physical filesystem directories. Outputs are
published to Photos using PhotoKit with the preserved creation date. For videos,
iOS preserves existing AVFoundation creation metadata and also falls back to
camera filename patterns such as `20260803_122921.mp4` when no embedded date is
available.
