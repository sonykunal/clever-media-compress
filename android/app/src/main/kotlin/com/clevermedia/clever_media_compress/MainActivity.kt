package com.clevermedia.clever_media_compress

import android.content.ContentValues
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.exifinterface.media.ExifInterface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "compressAndPublish") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            worker.execute {
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
        }
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }

    private fun compressAndPublish(call: MethodCall): Map<String, Any?> {
        val kind = call.argument<String>("mediaKind") ?: "image"
        if (kind != "image") {
            return failure("Video compression will be added through Media3 in the next engine milestone.")
        }

        val sourcePath = requiredString(call, "sourcePath")
        val sourceName = requiredString(call, "sourceName")
        val suffix = call.argument<String>("outputSuffix") ?: "_compressed"
        val quality = (call.argument<Int>("quality") ?: 72).coerceIn(20, 95)
        val scale = (call.argument<Double>("resolutionScale") ?: 1.0).coerceIn(0.25, 1.0)
        val preserveMetadata = call.argument<Boolean>("preserveMetadata") ?: true
        val preserveLocation = call.argument<Boolean>("preserveLocation") ?: true
        val source = File(sourcePath)
        require(source.isFile) { "The selected source file is no longer available." }

        val sourceExif = runCatching { ExifInterface(source.absolutePath) }.getOrNull()
        val captureMillis = sourceExif?.dateTimeOriginal ?: sourceExif?.dateTime
        val captureFingerprint = sourceExif?.let(::captureFingerprint)
        val bitmap = decodeScaled(source, scale)
        val outputName = "${sourceName.substringBeforeLast('.', sourceName)}$suffix.jpg"
        val temporary = File.createTempFile("clever-compress-", ".jpg", cacheDir)

        try {
            FileOutputStream(temporary).use { stream ->
                val jpegBitmap = flattenTransparency(bitmap)
                check(jpegBitmap.compress(Bitmap.CompressFormat.JPEG, quality, stream)) {
                    "The Android JPEG encoder could not write the output."
                }
                stream.flush()
                if (jpegBitmap !== bitmap) jpegBitmap.recycle()
            }

            if (preserveMetadata && sourceExif != null) {
                copyMetadata(
                    source = sourceExif,
                    targetPath = temporary.absolutePath,
                    keepLocation = preserveLocation,
                    width = bitmap.width,
                    height = bitmap.height,
                )
            }

            val verified = preserveMetadata &&
                captureFingerprint != null &&
                captureFingerprint == runCatching {
                    captureFingerprint(ExifInterface(temporary.absolutePath))
                }.getOrNull()
            val published = publishImage(temporary, outputName, captureMillis)

            return mapOf(
                "success" to true,
                "outputUri" to published.toString(),
                "outputName" to outputName,
                "outputBytes" to temporary.length(),
                "captureDateVerified" to verified,
                "message" to if (verified) {
                    "Capture date verified and published to the gallery."
                } else {
                    "Published, but no source EXIF capture date was available to verify."
                },
            )
        } finally {
            bitmap.recycle()
            temporary.delete()
        }
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
        source: ExifInterface,
        targetPath: String,
        keepLocation: Boolean,
        width: Int,
        height: Int,
    ) {
        val target = ExifInterface(targetPath)
        val excluded = if (keepLocation) emptySet() else GPS_TAGS
        for (tag in COPYABLE_TAGS) {
            if (tag !in excluded) source.getAttribute(tag)?.let { target.setAttribute(tag, it) }
        }
        target.setAttribute(ExifInterface.TAG_IMAGE_WIDTH, width.toString())
        target.setAttribute(ExifInterface.TAG_IMAGE_LENGTH, height.toString())
        target.setAttribute(ExifInterface.TAG_PIXEL_X_DIMENSION, width.toString())
        target.setAttribute(ExifInterface.TAG_PIXEL_Y_DIMENSION, height.toString())
        target.saveAttributes()
    }

    private fun captureFingerprint(exif: ExifInterface): String? {
        val date = exif.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL)
            ?: exif.getAttribute(ExifInterface.TAG_DATETIME)
            ?: return null
        val subsecond = exif.getAttribute(ExifInterface.TAG_SUBSEC_TIME_ORIGINAL).orEmpty()
        val offset = exif.getAttribute(ExifInterface.TAG_OFFSET_TIME_ORIGINAL).orEmpty()
        return "$date|$subsecond|$offset"
    }

    private fun publishImage(source: File, displayName: String, captureMillis: Long?): Uri {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                put(MediaStore.Images.Media.RELATIVE_PATH, "$DEFAULT_ALBUM/")
                put(MediaStore.Images.Media.IS_PENDING, 1)
                captureMillis?.let { put(MediaStore.Images.Media.DATE_TAKEN, it) }
            }
            val collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
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

        val pictures = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
        val album = File(pictures, "Clever Compress").apply { mkdirs() }
        val target = uniqueFile(album, displayName)
        source.copyTo(target)
        target.setLastModified(captureMillis ?: source.lastModified())
        MediaScannerConnection.scanFile(this, arrayOf(target.absolutePath), arrayOf("image/jpeg"), null)
        return Uri.fromFile(target)
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
        private const val DEFAULT_ALBUM = "Pictures/Clever Compress"

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
}
