package com.clevermedia.clever_media_compress

import android.app.Activity
import android.Manifest
import android.content.pm.PackageManager
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.database.Cursor
import android.media.MediaScannerConnection
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.exifinterface.media.ExifInterface
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.container.Mp4LocationData
import androidx.media3.container.Mp4OrientationData
import androidx.media3.container.Mp4TimestampData
import androidx.media3.effect.ScaleAndRotateTransformation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.InAppMp4Muxer
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.charset.StandardCharsets
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt

@UnstableApi
class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private var pendingPickerResult: MethodChannel.Result? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var waitingForMediaPermission = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickMedia" -> launchMediaPicker(result)
                "requestMediaLibraryAccess" -> requestMediaLibraryAccess(result)
                "openAppSettings" -> openAppSettings(result)
                "createVideoThumbnail" -> worker.execute {
                    try {
                        val path = createVideoThumbnail(call)
                        runOnUiThread { result.success(path) }
                    } catch (_: Throwable) {
                        runOnUiThread { result.success(null) }
                    }
                }
                "compressAndPublish" -> worker.execute {
                    try {
                        val payload = compressAndPublish(call)
                        runOnUiThread { result.success(payload) }
                    } catch (error: Throwable) {
                        runOnUiThread {
                            result.error(
                                "compression_failed",
                                error.message ?: "Android could not compress this file.",
                                null,
                            )
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun launchMediaPicker(result: MethodChannel.Result) {
        if (pendingPickerResult != null) {
            result.error("picker_active", "The media picker is already open.", null)
            return
        }
        pendingPickerResult = result
        if (needsMediaLibraryPermission()) {
            waitingForMediaPermission = true
            requestPermissions(mediaLibraryPermissions(), MEDIA_LIBRARY_PERMISSION_REQUEST)
            return
        }
        openMediaPicker()
    }

    private fun requestMediaLibraryAccess(result: MethodChannel.Result) {
        if (hasFullMediaLibraryAccess()) {
            result.success(mediaAccessPayload())
            return
        }
        if (pendingPermissionResult != null || pendingPickerResult != null) {
            result.error("permission_active", "The media permission prompt is already open.", null)
            return
        }
        pendingPermissionResult = result
        waitingForMediaPermission = true
        requestPermissions(mediaLibraryPermissions(), MEDIA_LIBRARY_PERMISSION_REQUEST)
    }

    private fun openAppSettings(result: MethodChannel.Result) {
        runCatching {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", packageName, null)
                },
            )
        }
        result.success(null)
    }

    private fun needsMediaLibraryPermission(): Boolean = !hasFullMediaLibraryAccess()

    private fun hasFullMediaLibraryAccess(): Boolean = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU ->
            checkSelfPermission(Manifest.permission.READ_MEDIA_IMAGES) ==
                PackageManager.PERMISSION_GRANTED &&
                checkSelfPermission(Manifest.permission.READ_MEDIA_VIDEO) ==
                    PackageManager.PERMISSION_GRANTED
        else -> checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun hasLimitedMediaLibraryAccess(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE &&
            checkSelfPermission(Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED) ==
            PackageManager.PERMISSION_GRANTED &&
            !hasFullMediaLibraryAccess()

    private fun mediaAccessPayload(): Map<String, Any?> {
        val status = when {
            hasFullMediaLibraryAccess() -> "full"
            hasLimitedMediaLibraryAccess() -> "limited"
            else -> "denied"
        }
        val message = when (status) {
            "full" -> "Full Photos and videos access is enabled."
            "limited" ->
                "Android is allowing only selected photos and videos. Choose Allow all photos and videos so Clever Compress can save outputs beside the original and verify dates."
            else ->
                "Full Photos and videos access is needed to save compressed media in the same folder and verify gallery dates."
        }
        return mapOf(
            "status" to status,
            "message" to message,
            "canOpenSettings" to (status != "full"),
        )
    }

    private fun mediaLibraryPermissions(): Array<String> = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE -> arrayOf(
            Manifest.permission.READ_MEDIA_IMAGES,
            Manifest.permission.READ_MEDIA_VIDEO,
            Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED,
        )
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> arrayOf(
            Manifest.permission.READ_MEDIA_IMAGES,
            Manifest.permission.READ_MEDIA_VIDEO,
        )
        else -> arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != MEDIA_LIBRARY_PERMISSION_REQUEST || !waitingForMediaPermission) return
        waitingForMediaPermission = false
        pendingPermissionResult?.let { result ->
            pendingPermissionResult = null
            result.success(mediaAccessPayload())
            return
        }
        // The system picker remains available after denial. A local item can still
        // be selected, but exact same-folder output requires the granted MediaStore
        // directory field and will explain that requirement if unavailable.
        openMediaPicker()
    }

    private fun openMediaPicker() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "video/*"))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        startActivityForResult(intent, PICK_MEDIA_REQUEST)
    }

    @Deprecated("The Flutter activity still forwards this callback for ACTION_OPEN_DOCUMENT.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_MEDIA_REQUEST) return
        val result = pendingPickerResult ?: return
        pendingPickerResult = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<Map<String, Any?>>())
            return
        }

        val uris = buildList {
            data.clipData?.let { clips ->
                for (index in 0 until clips.itemCount) add(clips.getItemAt(index).uri)
            }
            data.data?.let { add(it) }
        }.distinct()

        worker.execute {
            try {
                val selected = uris.map(::importPickedMedia)
                runOnUiThread { result.success(selected) }
            } catch (error: Throwable) {
                runOnUiThread {
                    result.error(
                        "picker_import_failed",
                        error.message ?: "Android could not read the selected media.",
                        null,
                    )
                }
            }
        }
    }

    private fun importPickedMedia(uri: Uri): Map<String, Any?> {
        runCatching {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        }
        val mimeType = contentResolver.getType(uri) ?: "application/octet-stream"
        val displayName = queryString(uri, OpenableColumns.DISPLAY_NAME)
            ?.takeIf(String::isNotBlank)
            ?: "selected-media-${System.currentTimeMillis()}"
        val safeName = displayName.replace(Regex("[\\/\\u0000]"), "_")
        val destinationDirectory = File(cacheDir, "picked-media/${UUID.randomUUID()}").apply {
            check(mkdirs() || isDirectory) { "Android could not prepare the media cache." }
        }
        val destination = File(destinationDirectory, safeName)
        contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(destination).use { output -> input.copyTo(output) }
        } ?: error("Android could not open $displayName.")
        val byteSize = destination.length()
        val mediaStoreDetails = resolveMediaStoreDetails(
            sourceUri = uri,
            mimeType = mimeType,
            displayName = displayName,
            byteSize = byteSize,
        )

        return mapOf(
            "path" to destination.absolutePath,
            "name" to displayName,
            "mimeType" to mimeType,
            "byteSize" to byteSize,
            "sourceUri" to uri.toString(),
            "sourceRelativePath" to mediaStoreDetails?.relativePath,
            "sourceCaptureMillis" to mediaStoreDetails?.captureMillis,
        )
    }

    private fun queryString(uri: Uri, column: String): String? = runCatching {
        contentResolver.query(uri, arrayOf(column), null, null, null)?.use { cursor ->
            if (!cursor.moveToFirst()) null else cursor.getString(0)
        }
    }.getOrNull()

    private fun resolveMediaStoreDetails(
        sourceUri: Uri,
        mimeType: String,
        displayName: String,
        byteSize: Long,
    ): MediaStoreDetails? {
        val directDetails = queryMediaStoreDetails(sourceUri)
        if (safeRelativePath(directDetails?.relativePath) != null) return directDetails

        val resolvedDetails = resolveMediaStoreUri(sourceUri, mimeType)?.let { mediaUri ->
            queryMediaStoreDetails(mediaUri)
        }
        if (safeRelativePath(resolvedDetails?.relativePath) != null) {
            return resolvedDetails?.withCaptureFallback(directDetails)
        }

        return findLocalMediaStoreMatch(mimeType, displayName, byteSize)
            ?.withCaptureFallback(resolvedDetails)
            ?.withCaptureFallback(directDetails)
    }

    private fun queryMediaStoreDetails(uri: Uri): MediaStoreDetails? {
        val projection = mutableListOf(
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.SIZE,
            MediaStore.Images.Media.DATE_TAKEN,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            projection.add(MediaStore.MediaColumns.RELATIVE_PATH)
        } else {
            projection.add(MediaStore.MediaColumns.DATA)
        }

        return runCatching {
            contentResolver.query(uri, projection.toTypedArray(), null, null, null)?.use { cursor ->
                if (!cursor.moveToFirst()) return@use null
                val relativePath = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    cursor.stringValue(MediaStore.MediaColumns.RELATIVE_PATH)
                } else {
                    cursor.stringValue(MediaStore.MediaColumns.DATA)
                        ?.let(::relativePathFromAbsolutePath)
                }
                val captureMillis = cursor.longValue(MediaStore.Images.Media.DATE_TAKEN)
                    ?.takeIf { it > 0 }
                MediaStoreDetails(relativePath = relativePath, captureMillis = captureMillis)
            }
        }.getOrNull()
    }

    private fun findLocalMediaStoreMatch(
        mimeType: String,
        displayName: String,
        byteSize: Long,
    ): MediaStoreDetails? {
        val collection = mediaStoreCollection(mimeType)
        val projection = mutableListOf(
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.SIZE,
            MediaStore.Images.Media.DATE_TAKEN,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            projection.add(MediaStore.MediaColumns.RELATIVE_PATH)
        } else {
            projection.add(MediaStore.MediaColumns.DATA)
        }
        val selection = "${MediaStore.MediaColumns.DISPLAY_NAME} = ? AND " +
            "${MediaStore.MediaColumns.SIZE} = ?"
        val selectionArgs = arrayOf(displayName, byteSize.toString())

        return runCatching {
            contentResolver.query(
                collection,
                projection.toTypedArray(),
                selection,
                selectionArgs,
                "${MediaStore.MediaColumns.DATE_ADDED} DESC",
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    val relativePath = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        cursor.stringValue(MediaStore.MediaColumns.RELATIVE_PATH)
                    } else {
                        cursor.stringValue(MediaStore.MediaColumns.DATA)
                            ?.let(::relativePathFromAbsolutePath)
                    }
                    if (safeRelativePath(relativePath) == null) continue
                    val captureMillis = cursor.longValue(MediaStore.Images.Media.DATE_TAKEN)
                        ?.takeIf { it > 0 }
                    return@use MediaStoreDetails(
                        relativePath = relativePath,
                        captureMillis = captureMillis,
                    )
                }
                null
            }
        }.getOrNull() ?: findUniqueNameMediaStoreMatch(
            collection = collection,
            projection = projection.toTypedArray(),
            displayName = displayName,
        )
    }

    private fun findUniqueNameMediaStoreMatch(
        collection: Uri,
        projection: Array<String>,
        displayName: String,
    ): MediaStoreDetails? {
        val matches = mutableListOf<MediaStoreDetails>()
        return runCatching {
            contentResolver.query(
                collection,
                projection,
                "${MediaStore.MediaColumns.DISPLAY_NAME} = ?",
                arrayOf(displayName),
                "${MediaStore.MediaColumns.DATE_ADDED} DESC",
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    val relativePath = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        cursor.stringValue(MediaStore.MediaColumns.RELATIVE_PATH)
                    } else {
                        cursor.stringValue(MediaStore.MediaColumns.DATA)
                            ?.let(::relativePathFromAbsolutePath)
                    }
                    if (safeRelativePath(relativePath) == null) continue
                    val captureMillis = cursor.longValue(MediaStore.Images.Media.DATE_TAKEN)
                        ?.takeIf { it > 0 }
                    matches.add(MediaStoreDetails(relativePath, captureMillis))
                    val distinctFolders = matches.mapNotNull { safeRelativePath(it.relativePath) }
                        .distinct()
                    if (distinctFolders.size > 1) return@use null
                }

                val distinctFolders = matches.mapNotNull { safeRelativePath(it.relativePath) }
                    .distinct()
                if (distinctFolders.size == 1) {
                    matches.first().copy(relativePath = distinctFolders.first())
                } else {
                    null
                }
            }
        }.getOrNull()
    }

    private fun resolveMediaStoreUri(uri: Uri, mimeType: String): Uri? {
        if (!DocumentsContract.isDocumentUri(this, uri) ||
            uri.authority != "com.android.providers.media.documents"
        ) return null
        val parts = runCatching { DocumentsContract.getDocumentId(uri).split(':') }
            .getOrNull() ?: return null
        val id = parts.getOrNull(1)?.toLongOrNull() ?: return null
        val collection = mediaStoreCollection(mimeType)
        return ContentUris.withAppendedId(collection, id)
    }

    private fun mediaStoreCollection(mimeType: String): Uri = if (mimeType.startsWith("video/")) {
        MediaStore.Video.Media.EXTERNAL_CONTENT_URI
    } else {
        MediaStore.Images.Media.EXTERNAL_CONTENT_URI
    }

    private fun relativePathFromAbsolutePath(path: String): String? = runCatching {
        File(path).parentFile
            ?.relativeTo(Environment.getExternalStorageDirectory())
            ?.path
            ?.trimEnd('/')
            ?.plus('/')
    }.getOrNull()

    private fun resolveSourceMediaStoreDetails(
        call: MethodCall,
        mimeType: String,
        sourceName: String,
        byteSize: Long,
    ): MediaStoreDetails? {
        val sourceUri = call.argument<String>("sourceUri")
            ?.let { runCatching { Uri.parse(it) }.getOrNull() }
        return sourceUri?.let {
            resolveMediaStoreDetails(
                sourceUri = it,
                mimeType = mimeType,
                displayName = sourceName,
                byteSize = byteSize,
            )
        } ?: findLocalMediaStoreMatch(mimeType, sourceName, byteSize)
    }

    private fun Cursor.stringValue(column: String): String? {
        val index = getColumnIndex(column)
        return if (index < 0 || isNull(index)) null else getString(index)
    }

    private fun Cursor.longValue(column: String): Long? {
        val index = getColumnIndex(column)
        return if (index < 0 || isNull(index)) null else getLong(index)
    }

    private fun preferredRelativePath(primary: String?, fallback: String?): String? =
        safeRelativePath(primary) ?: safeRelativePath(fallback)

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }

    private fun compressAndPublish(call: MethodCall): Map<String, Any?> {
        val kind = call.argument<String>("mediaKind") ?: "image"
        return when (kind) {
            "image" -> compressImageAndPublish(call)
            "video" -> compressVideoAndPublish(call)
            else -> failure("Unsupported media category: $kind")
        }
    }

    private fun createVideoThumbnail(call: MethodCall): String? {
        val sourcePath = requiredString(call, "sourcePath")
        val source = File(sourcePath)
        if (!source.isFile) return null
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(source.absolutePath)
            val frame = retriever.getFrameAtTime(1_000_000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                ?: retriever.frameAtTime
                ?: return null
            val scale = minOf(1.0, 360.0 / max(frame.width, frame.height).coerceAtLeast(1))
            val thumbnail = if (scale < 1.0) {
                Bitmap.createScaledBitmap(
                    frame,
                    max(1, (frame.width * scale).roundToInt()),
                    max(1, (frame.height * scale).roundToInt()),
                    true,
                ).also { frame.recycle() }
            } else {
                frame
            }
            val output = File.createTempFile("clever-video-thumb-", ".jpg", cacheDir)
            FileOutputStream(output).use { stream ->
                thumbnail.compress(Bitmap.CompressFormat.JPEG, 76, stream)
            }
            thumbnail.recycle()
            output.absolutePath
        } finally {
            retriever.release()
        }
    }

    private fun compressImageAndPublish(call: MethodCall): Map<String, Any?> {
        val sourcePath = requiredString(call, "sourcePath")
        val sourceName = requiredString(call, "sourceName")
        val sourceRelativePath = call.argument<String>("sourceRelativePath")
        val suffix = call.argument<String>("outputSuffix") ?: "_compressed"
        val quality = (call.argument<Int>("quality") ?: 72).coerceIn(20, 95)
        val scale = (call.argument<Double>("resolutionScale") ?: 1.0).coerceIn(0.25, 1.0)
        val preserveMetadata = call.argument<Boolean>("preserveMetadata") ?: true
        val preserveLocation = call.argument<Boolean>("preserveLocation") ?: true
        val source = File(sourcePath)
        require(source.isFile) { "The selected source file is no longer available." }

        val sourceExif = runCatching { ExifInterface(source.absolutePath) }.getOrNull()
        val galleryCaptureMillis = call.argument<Number>("sourceCaptureMillis")?.toLong()
        val captureStamp = sourceExif?.let(::captureStamp)
            ?: galleryCaptureMillis?.let(CaptureStamp::fromEpochMillis)
        val captureMillis = galleryCaptureMillis ?: captureStamp?.toEpochMillis()
        val bitmap = decodeScaled(source, scale)
        val format = ImageOutputFormat.fromSourceName(sourceName)
        val sourceMediaStoreDetails = resolveSourceMediaStoreDetails(
            call = call,
            mimeType = format.mimeType,
            sourceName = sourceName,
            byteSize = source.length(),
        )
        val outputName = "${sourceName.substringBeforeLast('.', sourceName)}$suffix.${format.extension}"
        val temporary = File.createTempFile("clever-compress-", ".${format.extension}", cacheDir)

        try {
            FileOutputStream(temporary).use { stream ->
                val encodedBitmap = if (format.flattenTransparency) {
                    flattenTransparency(bitmap)
                } else {
                    bitmap
                }
                check(encodedBitmap.compress(format.compressFormat, quality, stream)) {
                    "The Android image encoder could not write the output."
                }
                stream.flush()
                if (encodedBitmap !== bitmap) encodedBitmap.recycle()
            }

            if (preserveMetadata && captureStamp != null) {
                copyMetadata(
                    source = sourceExif,
                    captureStamp = captureStamp,
                    targetPath = temporary.absolutePath,
                    keepLocation = preserveLocation,
                    width = bitmap.width,
                    height = bitmap.height,
                )
            }

            val embeddedDateVerified = preserveMetadata &&
                captureStamp != null &&
                captureStamp.fingerprint == runCatching {
                    captureStamp(ExifInterface(temporary.absolutePath))?.fingerprint
                }.getOrNull()
            val published = publishMedia(
                source = temporary,
                displayName = outputName,
                mimeType = format.mimeType,
                captureMillis = captureMillis,
                sourceRelativePath = preferredRelativePath(
                    sourceRelativePath,
                    sourceMediaStoreDetails?.relativePath,
                ),
                isVideo = false,
            )
            val galleryDateVerified = captureMillis != null &&
                verifyPublishedDate(published, captureMillis)
            val verified = embeddedDateVerified && galleryDateVerified

            return mapOf(
                "success" to true,
                "outputUri" to published.toString(),
                "outputName" to outputName,
                "outputBytes" to temporary.length(),
                "captureDateVerified" to verified,
                "message" to when {
                    verified -> "Capture date verified in the file and Android gallery."
                    captureStamp == null ->
                        "Published, but the source had no embedded capture date to preserve."
                    !embeddedDateVerified ->
                        "Published, but Android could not verify the embedded capture date."
                    else ->
                        "Published, but Android Gallery did not report the expected capture date."
                },
            )
        } finally {
            bitmap.recycle()
            temporary.delete()
        }
    }

    private fun compressVideoAndPublish(call: MethodCall): Map<String, Any?> {
        val source = File(requiredString(call, "sourcePath"))
        require(source.isFile) { "The selected source video is no longer available." }
        val sourceName = requiredString(call, "sourceName")
        val sourceRelativePath = call.argument<String>("sourceRelativePath")
        val suffix = call.argument<String>("outputSuffix") ?: "_compressed"
        val quality = (call.argument<Int>("quality") ?: 72).coerceIn(20, 95)
        val scale = (call.argument<Double>("resolutionScale") ?: 1.0).coerceIn(0.25, 1.0)
        val preserveMetadata = call.argument<Boolean>("preserveMetadata") ?: true
        val preserveLocation = call.argument<Boolean>("preserveLocation") ?: true
        val galleryCaptureMillis = call.argument<Number>("sourceCaptureMillis")?.toLong()
        val sourceMediaStoreDetails = resolveSourceMediaStoreDetails(
            call = call,
            mimeType = "video/mp4",
            sourceName = sourceName,
            byteSize = source.length(),
        )

        val retriever = MediaMetadataRetriever()
        val originalBitrate: Int
        val retrieverCaptureMillis: Long?
        val embeddedLocation: Pair<Float, Float>?
        try {
            retriever.setDataSource(source.absolutePath)
            originalBitrate = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)
                ?.toIntOrNull() ?: 8_000_000
            retrieverCaptureMillis = parseVideoDate(
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DATE),
            )
            embeddedLocation = parseIso6709Location(
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_LOCATION),
            )
        } finally {
            retriever.release()
        }

        val embeddedCaptureMillis = retrieverCaptureMillis
            ?: mp4HeaderCaptureMillis(source)
            ?: captureMillisFromFileName(sourceName)
        val captureMillis = galleryCaptureMillis ?: embeddedCaptureMillis
        val baseName = sourceName.substringBeforeLast('.', sourceName)
        val outputName = "$baseName$suffix.mp4"
        val temporary = File(cacheDir, "clever-video-${UUID.randomUUID()}.mp4")
        val targetBitrate = (originalBitrate * (quality / 100.0) * scale * scale)
            .roundToInt()
            .coerceIn(350_000, originalBitrate.coerceAtLeast(350_000))
        val latch = CountDownLatch(1)
        var exportError: Throwable? = null

        try {
            runOnUiThread {
                val metadataProvider = InAppMp4Muxer.MetadataProvider { entries ->
                    if (!preserveMetadata) {
                        entries.removeAll { it !is Mp4OrientationData }
                    } else {
                        captureMillis?.let { millis ->
                            entries.removeAll { it is Mp4TimestampData }
                            val mp4Seconds = Mp4TimestampData.unixTimeToMp4TimeSeconds(millis)
                            entries.add(Mp4TimestampData(mp4Seconds, mp4Seconds))
                        }
                        if (!preserveLocation) {
                            entries.removeAll { it is Mp4LocationData }
                        } else {
                            embeddedLocation?.let { (latitude, longitude) ->
                                entries.removeAll { it is Mp4LocationData }
                                entries.add(Mp4LocationData(latitude, longitude))
                            }
                        }
                    }
                }
                val encoderFactory = DefaultEncoderFactory.Builder(this)
                    .setRequestedVideoEncoderSettings(
                        VideoEncoderSettings.Builder().setBitrate(targetBitrate).build(),
                    )
                    .setEnableFallback(true)
                    .build()
                val videoEffects = mutableListOf<Effect>()
                if (scale < 0.999) {
                    videoEffects.add(
                        ScaleAndRotateTransformation.Builder()
                            .setScale(scale.toFloat(), scale.toFloat())
                            .build(),
                    )
                }
                val editedMedia = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(source)))
                    .setEffects(Effects(emptyList(), videoEffects))
                    .setFlattenForSlowMotion(true)
                    .build()
                Transformer.Builder(this)
                    .setVideoMimeType(MimeTypes.VIDEO_H264)
                    .setAudioMimeType(MimeTypes.AUDIO_AAC)
                    .setEncoderFactory(encoderFactory)
                    .setMuxerFactory(InAppMp4Muxer.Factory(metadataProvider))
                    .addListener(
                        object : Transformer.Listener {
                            override fun onCompleted(
                                composition: Composition,
                                exportResult: ExportResult,
                            ) {
                                latch.countDown()
                            }

                            override fun onError(
                                composition: Composition,
                                exportResult: ExportResult,
                                exportException: ExportException,
                            ) {
                                exportError = exportException
                                latch.countDown()
                            }
                        },
                    )
                    .build()
                    .start(editedMedia, temporary.absolutePath)
            }
            latch.await()
            exportError?.let { throw it }
            check(temporary.isFile && temporary.length() > 0) {
                "Android produced an empty video output."
            }
            val embeddedDateVerified = preserveMetadata && captureMillis != null &&
                videoCaptureMillis(temporary)?.let {
                    kotlin.math.abs(it - captureMillis) < 1_000
                } == true

            val published = publishMedia(
                source = temporary,
                displayName = outputName,
                mimeType = "video/mp4",
                captureMillis = captureMillis,
                sourceRelativePath = preferredRelativePath(
                    sourceRelativePath,
                    sourceMediaStoreDetails?.relativePath,
                ),
                isVideo = true,
            )
            val galleryDateVerified = captureMillis != null &&
                verifyPublishedDate(published, captureMillis)
            val verified = embeddedDateVerified && galleryDateVerified
            return mapOf(
                "success" to true,
                "outputUri" to published.toString(),
                "outputName" to outputName,
                "outputBytes" to temporary.length(),
                "captureDateVerified" to verified,
                "message" to when {
                    verified -> "Video capture date verified in MP4 metadata and Android gallery."
                    captureMillis == null ->
                        "Video saved, but no source capture date was available to verify."
                    !embeddedDateVerified ->
                        "Video saved, but Android could not verify the MP4 capture timestamp."
                    else ->
                        "Video saved, but Android Gallery did not report the expected capture date."
                },
            )
        } finally {
            temporary.delete()
        }
    }

    private fun parseVideoDate(value: String?): Long? {
        if (value.isNullOrBlank()) return null
        val patterns = listOf(
            "yyyyMMdd'T'HHmmss.SSSZ",
            "yyyyMMdd'T'HHmmssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXX",
        )
        return patterns.firstNotNullOfOrNull { pattern ->
            runCatching {
                SimpleDateFormat(pattern, Locale.US).apply { isLenient = false }.parse(value)?.time
            }.getOrNull()
        }
    }

    private fun videoCaptureMillis(file: File): Long? {
        val retriever = MediaMetadataRetriever()
        val retrieverMillis = try {
            retriever.setDataSource(file.absolutePath)
            parseVideoDate(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DATE))
        } catch (_: Throwable) {
            null
        } finally {
            retriever.release()
        }
        return retrieverMillis ?: mp4HeaderCaptureMillis(file)
    }

    private fun mp4HeaderCaptureMillis(file: File): Long? = runCatching {
        RandomAccessFile(file, "r").use { input ->
            val moov = findMp4Box(input, start = 0, end = input.length(), target = "moov")
                ?: return@use null
            val mvhd = findMp4Box(
                input,
                start = moov.dataStart,
                end = moov.end,
                target = "mvhd",
            ) ?: return@use null
            readMvhdCreationMillis(input, mvhd)
        }
    }.getOrNull()

    private fun findMp4Box(
        input: RandomAccessFile,
        start: Long,
        end: Long,
        target: String,
    ): Mp4Box? {
        var position = start
        while (position + 8 <= end) {
            input.seek(position)
            val size32 = input.readUnsignedInt()
            val type = input.readAscii(4)
            var headerSize = 8L
            val boxSize = when (size32) {
                0L -> end - position
                1L -> {
                    headerSize = 16L
                    input.readLong()
                }
                else -> size32
            }
            if (boxSize < headerSize || position + boxSize > end) return null
            val box = Mp4Box(
                type = type,
                dataStart = position + headerSize,
                end = position + boxSize,
            )
            if (type == target) return box
            position += boxSize
        }
        return null
    }

    private fun readMvhdCreationMillis(input: RandomAccessFile, box: Mp4Box): Long? {
        input.seek(box.dataStart)
        val version = input.readUnsignedByte()
        input.skipBytes(3)
        val creationSeconds = if (version == 1) {
            input.readLong()
        } else {
            input.readUnsignedInt()
        }
        val unixSeconds = creationSeconds - MP4_UNIX_EPOCH_OFFSET_SECONDS
        if (unixSeconds <= 0) return null
        return unixSeconds * 1_000
    }

    private fun captureMillisFromFileName(name: String): Long? {
        val match = Regex("""(\d{8})[_-](\d{6})""").find(name) ?: return null
        return runCatching {
            SimpleDateFormat("yyyyMMddHHmmss", Locale.US).apply {
                isLenient = false
                timeZone = TimeZone.getDefault()
            }.parse(match.groupValues[1] + match.groupValues[2])?.time
        }.getOrNull()
    }

    private fun RandomAccessFile.readUnsignedInt(): Long = readInt().toLong() and 0xffffffffL

    private fun RandomAccessFile.readAscii(length: Int): String {
        val bytes = ByteArray(length)
        readFully(bytes)
        return String(bytes, StandardCharsets.US_ASCII)
    }

    private fun parseIso6709Location(value: String?): Pair<Float, Float>? {
        if (value.isNullOrBlank()) return null
        val match = Regex("^([+-]\\d+(?:\\.\\d+)?)([+-]\\d+(?:\\.\\d+)?)").find(value)
            ?: return null
        val latitude = match.groupValues[1].toFloatOrNull() ?: return null
        val longitude = match.groupValues[2].toFloatOrNull() ?: return null
        return latitude to longitude
    }

    private fun decodeScaled(source: File, scale: Double): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(source.absolutePath, bounds)
        require(bounds.outWidth > 0 && bounds.outHeight > 0) {
            "This image format is not supported by the Android decoder."
        }

        val targetWidth = max(1, (bounds.outWidth * scale).roundToInt())
        val targetHeight = max(1, (bounds.outHeight * scale).roundToInt())
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= targetWidth &&
            bounds.outHeight / (sample * 2) >= targetHeight
        ) {
            sample *= 2
        }

        val decoded = BitmapFactory.decodeFile(
            source.absolutePath,
            BitmapFactory.Options().apply {
                inSampleSize = sample
                inPreferredConfig = Bitmap.Config.ARGB_8888
            },
        ) ?: error("Android could not decode the selected image.")

        if (decoded.width == targetWidth && decoded.height == targetHeight) return decoded
        val scaled = Bitmap.createScaledBitmap(decoded, targetWidth, targetHeight, true)
        if (scaled !== decoded) decoded.recycle()
        return scaled
    }

    private fun flattenTransparency(source: Bitmap): Bitmap {
        if (!source.hasAlpha()) return source
        return Bitmap.createBitmap(source.width, source.height, Bitmap.Config.RGB_565).also {
            val canvas = Canvas(it)
            canvas.drawColor(Color.WHITE)
            canvas.drawBitmap(source, 0f, 0f, null)
        }
    }

    private fun copyMetadata(
        source: ExifInterface?,
        captureStamp: CaptureStamp,
        targetPath: String,
        keepLocation: Boolean,
        width: Int,
        height: Int,
    ) {
        val target = ExifInterface(targetPath)
        val excluded = if (keepLocation) emptySet() else GPS_TAGS
        if (source != null) {
            for (tag in COPYABLE_TAGS) {
                if (tag !in excluded) source.getAttribute(tag)?.let { target.setAttribute(tag, it) }
            }
        }
        target.setAttribute(ExifInterface.TAG_DATETIME_ORIGINAL, captureStamp.date)
        captureStamp.subsecond.takeIf(String::isNotEmpty)?.let {
                target.setAttribute(ExifInterface.TAG_SUBSEC_TIME_ORIGINAL, it)
        }
        captureStamp.offset.takeIf(String::isNotEmpty)?.let {
                target.setAttribute(ExifInterface.TAG_OFFSET_TIME_ORIGINAL, it)
        }
        target.setAttribute(ExifInterface.TAG_IMAGE_WIDTH, width.toString())
        target.setAttribute(ExifInterface.TAG_IMAGE_LENGTH, height.toString())
        target.setAttribute(ExifInterface.TAG_PIXEL_X_DIMENSION, width.toString())
        target.setAttribute(ExifInterface.TAG_PIXEL_Y_DIMENSION, height.toString())
        target.saveAttributes()
    }

    private fun captureStamp(exif: ExifInterface): CaptureStamp? {
        val original = exif.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL)
        val digitized = exif.getAttribute(ExifInterface.TAG_DATETIME_DIGITIZED)
        val date = original ?: digitized
            ?: exif.getAttribute(ExifInterface.TAG_DATETIME)
            ?: return null
        val subsecond = when {
            original != null -> exif.getAttribute(ExifInterface.TAG_SUBSEC_TIME_ORIGINAL)
            digitized != null -> exif.getAttribute(ExifInterface.TAG_SUBSEC_TIME_DIGITIZED)
            else -> exif.getAttribute(ExifInterface.TAG_SUBSEC_TIME)
        }.orEmpty()
        val offset = when {
            original != null -> exif.getAttribute(ExifInterface.TAG_OFFSET_TIME_ORIGINAL)
            digitized != null -> exif.getAttribute(ExifInterface.TAG_OFFSET_TIME_DIGITIZED)
            else -> exif.getAttribute(ExifInterface.TAG_OFFSET_TIME)
        }.orEmpty()
        return CaptureStamp(date, subsecond, offset)
    }

    private fun publishMedia(
        source: File,
        displayName: String,
        mimeType: String,
        captureMillis: Long?,
        sourceRelativePath: String?,
        isVideo: Boolean,
    ): Uri {
        val outputDirectory = safeRelativePath(sourceRelativePath)
            ?: error(
                "Android did not expose this item's original local folder. " +
                    "Allow full Photos and videos permission, then choose a locally stored " +
                    "Gallery or Files item. Cloud-only items cannot be saved beside the original.",
            )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
                put(MediaStore.Images.Media.MIME_TYPE, mimeType)
                put(MediaStore.Images.Media.RELATIVE_PATH, outputDirectory)
                put(MediaStore.Images.Media.IS_PENDING, 1)
                captureMillis?.let { put(MediaStore.Images.Media.DATE_TAKEN, it) }
            }
            val collection = if (isVideo) {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            }
            val uri = contentResolver.insert(collection, values)
                ?: error("Android MediaStore refused to create the output file.")
            try {
                contentResolver.openOutputStream(uri, "w")?.use { output ->
                    source.inputStream().use { input -> input.copyTo(output) }
                } ?: error("Android could not open the gallery output stream.")
                contentResolver.update(
                    uri,
                    ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) },
                    null,
                    null,
                )
                return uri
            } catch (error: Throwable) {
                contentResolver.delete(uri, null, null)
                throw error
            }
        }

        val album = File(Environment.getExternalStorageDirectory(), outputDirectory).apply {
            mkdirs()
        }
        val target = uniqueFile(album, displayName)
        source.copyTo(target)
        target.setLastModified(captureMillis ?: source.lastModified())
        MediaScannerConnection.scanFile(this, arrayOf(target.absolutePath), arrayOf(mimeType), null)
        return Uri.fromFile(target)
    }

    private fun safeRelativePath(path: String?): String? {
        val normalized = path?.trim()?.replace('\\', '/')?.takeIf(String::isNotEmpty)
            ?: return null
        if (normalized.startsWith('/') || normalized.split('/').any { it == ".." }) return null
        return normalized.trimEnd('/') + "/"
    }

    private fun verifyPublishedDate(uri: Uri, expectedMillis: Long): Boolean {
        if (uri.scheme == "file") {
            return File(uri.path.orEmpty()).lastModified().let {
                kotlin.math.abs(it - expectedMillis) < 1_000
            }
        }
        return runCatching {
            contentResolver.query(
                uri,
                arrayOf(MediaStore.Images.Media.DATE_TAKEN),
                null,
                null,
                null,
            )?.use { cursor ->
                cursor.moveToFirst() &&
                    kotlin.math.abs(cursor.getLong(0) - expectedMillis) < 1_000
            } ?: false
        }.getOrDefault(false)
    }

    private fun uniqueFile(directory: File, displayName: String): File {
        val desired = File(directory, displayName)
        if (!desired.exists()) return desired
        val base = displayName.substringBeforeLast('.', displayName)
        val extension = displayName.substringAfterLast('.', "jpg")
        var counter = 2
        while (true) {
            val candidate = File(directory, "$base ($counter).$extension")
            if (!candidate.exists()) return candidate
            counter++
        }
    }

    private fun requiredString(call: MethodCall, key: String): String =
        call.argument<String>(key)?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("Missing native argument: $key")

    private fun failure(message: String): Map<String, Any?> = mapOf(
        "success" to false,
        "captureDateVerified" to false,
        "message" to message,
    )

    companion object {
        private const val CHANNEL = "clever_media_compress/media"
        private const val PICK_MEDIA_REQUEST = 7041
        private const val MEDIA_LIBRARY_PERMISSION_REQUEST = 7042
        private const val MP4_UNIX_EPOCH_OFFSET_SECONDS = 2_082_844_800L

        private val GPS_TAGS = setOf(
            ExifInterface.TAG_GPS_LATITUDE,
            ExifInterface.TAG_GPS_LATITUDE_REF,
            ExifInterface.TAG_GPS_LONGITUDE,
            ExifInterface.TAG_GPS_LONGITUDE_REF,
            ExifInterface.TAG_GPS_ALTITUDE,
            ExifInterface.TAG_GPS_ALTITUDE_REF,
            ExifInterface.TAG_GPS_TIMESTAMP,
            ExifInterface.TAG_GPS_DATESTAMP,
            ExifInterface.TAG_GPS_PROCESSING_METHOD,
        )

        private val COPYABLE_TAGS = listOf(
            ExifInterface.TAG_APERTURE_VALUE,
            ExifInterface.TAG_ARTIST,
            ExifInterface.TAG_BITS_PER_SAMPLE,
            ExifInterface.TAG_BODY_SERIAL_NUMBER,
            ExifInterface.TAG_BRIGHTNESS_VALUE,
            ExifInterface.TAG_CAMERA_OWNER_NAME,
            ExifInterface.TAG_COLOR_SPACE,
            ExifInterface.TAG_COMPONENTS_CONFIGURATION,
            ExifInterface.TAG_COMPRESSED_BITS_PER_PIXEL,
            ExifInterface.TAG_COMPRESSION,
            ExifInterface.TAG_CONTRAST,
            ExifInterface.TAG_COPYRIGHT,
            ExifInterface.TAG_DATETIME,
            ExifInterface.TAG_DATETIME_DIGITIZED,
            ExifInterface.TAG_DATETIME_ORIGINAL,
            ExifInterface.TAG_DEVICE_SETTING_DESCRIPTION,
            ExifInterface.TAG_DIGITAL_ZOOM_RATIO,
            ExifInterface.TAG_EXIF_VERSION,
            ExifInterface.TAG_EXPOSURE_BIAS_VALUE,
            ExifInterface.TAG_EXPOSURE_INDEX,
            ExifInterface.TAG_EXPOSURE_MODE,
            ExifInterface.TAG_EXPOSURE_PROGRAM,
            ExifInterface.TAG_EXPOSURE_TIME,
            ExifInterface.TAG_FLASH,
            ExifInterface.TAG_FLASH_ENERGY,
            ExifInterface.TAG_FLASHPIX_VERSION,
            ExifInterface.TAG_FOCAL_LENGTH,
            ExifInterface.TAG_FOCAL_LENGTH_IN_35MM_FILM,
            ExifInterface.TAG_FOCAL_PLANE_RESOLUTION_UNIT,
            ExifInterface.TAG_FOCAL_PLANE_X_RESOLUTION,
            ExifInterface.TAG_FOCAL_PLANE_Y_RESOLUTION,
            ExifInterface.TAG_GAIN_CONTROL,
            ExifInterface.TAG_GAMMA,
            ExifInterface.TAG_IMAGE_DESCRIPTION,
            ExifInterface.TAG_IMAGE_UNIQUE_ID,
            ExifInterface.TAG_ISO_SPEED_RATINGS,
            ExifInterface.TAG_JPEG_INTERCHANGE_FORMAT,
            ExifInterface.TAG_JPEG_INTERCHANGE_FORMAT_LENGTH,
            ExifInterface.TAG_LENS_MAKE,
            ExifInterface.TAG_LENS_MODEL,
            ExifInterface.TAG_LENS_SERIAL_NUMBER,
            ExifInterface.TAG_LENS_SPECIFICATION,
            ExifInterface.TAG_LIGHT_SOURCE,
            ExifInterface.TAG_MAKE,
            ExifInterface.TAG_MAX_APERTURE_VALUE,
            ExifInterface.TAG_METERING_MODE,
            ExifInterface.TAG_MODEL,
            ExifInterface.TAG_OFFSET_TIME,
            ExifInterface.TAG_OFFSET_TIME_DIGITIZED,
            ExifInterface.TAG_OFFSET_TIME_ORIGINAL,
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.TAG_PHOTOGRAPHIC_SENSITIVITY,
            ExifInterface.TAG_RECOMMENDED_EXPOSURE_INDEX,
            ExifInterface.TAG_SATURATION,
            ExifInterface.TAG_SCENE_CAPTURE_TYPE,
            ExifInterface.TAG_SCENE_TYPE,
            ExifInterface.TAG_SENSING_METHOD,
            ExifInterface.TAG_SHARPNESS,
            ExifInterface.TAG_SHUTTER_SPEED_VALUE,
            ExifInterface.TAG_SOFTWARE,
            ExifInterface.TAG_SUBJECT_AREA,
            ExifInterface.TAG_SUBJECT_DISTANCE,
            ExifInterface.TAG_SUBJECT_DISTANCE_RANGE,
            ExifInterface.TAG_SUBSEC_TIME,
            ExifInterface.TAG_SUBSEC_TIME_DIGITIZED,
            ExifInterface.TAG_SUBSEC_TIME_ORIGINAL,
            ExifInterface.TAG_USER_COMMENT,
            ExifInterface.TAG_WHITE_BALANCE,
            ExifInterface.TAG_X_RESOLUTION,
            ExifInterface.TAG_Y_CB_CR_POSITIONING,
            ExifInterface.TAG_Y_RESOLUTION,
            ExifInterface.TAG_XMP,
        ) + GPS_TAGS
    }

    private data class CaptureStamp(
        val date: String,
        val subsecond: String,
        val offset: String,
    ) {
        val fingerprint: String get() = "$date|$subsecond|$offset"

        fun toEpochMillis(): Long? = runCatching {
            val formatter = SimpleDateFormat("yyyy:MM:dd HH:mm:ss", Locale.US).apply {
                isLenient = false
                timeZone = if (offset.matches(Regex("[+-]\\d{2}:\\d{2}"))) {
                    TimeZone.getTimeZone("GMT$offset")
                } else {
                    TimeZone.getDefault()
                }
            }
            val base = formatter.parse(date)?.time ?: return null
            val millis = subsecond.filter(Char::isDigit).take(3).padEnd(3, '0')
                .toIntOrNull() ?: 0
            base + millis
        }.getOrNull()

        companion object {
            fun fromEpochMillis(millis: Long): CaptureStamp {
                val formatter = SimpleDateFormat("yyyy:MM:dd HH:mm:ss", Locale.US).apply {
                    timeZone = TimeZone.getDefault()
                }
                val offsetFormatter = SimpleDateFormat("XXX", Locale.US).apply {
                    timeZone = TimeZone.getDefault()
                }
                return CaptureStamp(
                    date = formatter.format(millis),
                    subsecond = (millis % 1_000).toString().padStart(3, '0'),
                    offset = offsetFormatter.format(millis),
                )
            }
        }
    }

    private data class MediaStoreDetails(
        val relativePath: String?,
        val captureMillis: Long?,
    ) {
        fun withCaptureFallback(fallback: MediaStoreDetails?): MediaStoreDetails = copy(
            captureMillis = captureMillis ?: fallback?.captureMillis,
        )
    }

    private data class Mp4Box(
        val type: String,
        val dataStart: Long,
        val end: Long,
    )

    private data class ImageOutputFormat(
        val extension: String,
        val mimeType: String,
        val compressFormat: Bitmap.CompressFormat,
        val flattenTransparency: Boolean,
    ) {
        companion object {
            fun fromSourceName(sourceName: String): ImageOutputFormat {
                val sourceExtension = sourceName.substringAfterLast('.', "jpg")
                return when (sourceExtension.lowercase(Locale.US)) {
                    "png" -> ImageOutputFormat(
                        extension = sourceExtension,
                        mimeType = "image/png",
                        compressFormat = Bitmap.CompressFormat.PNG,
                        flattenTransparency = false,
                    )
                    "webp" -> ImageOutputFormat(
                        extension = sourceExtension,
                        mimeType = "image/webp",
                        compressFormat = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            Bitmap.CompressFormat.WEBP_LOSSY
                        } else {
                            @Suppress("DEPRECATION")
                            Bitmap.CompressFormat.WEBP
                        },
                        flattenTransparency = false,
                    )
                    "jpeg" -> ImageOutputFormat(
                        extension = sourceExtension,
                        mimeType = "image/jpeg",
                        compressFormat = Bitmap.CompressFormat.JPEG,
                        flattenTransparency = true,
                    )
                    else -> ImageOutputFormat(
                        extension = if (sourceExtension.equals("jpg", true)) sourceExtension else "jpg",
                        mimeType = "image/jpeg",
                        compressFormat = Bitmap.CompressFormat.JPEG,
                        flattenTransparency = true,
                    )
                }
            }
        }
    }
}
