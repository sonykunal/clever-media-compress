import 'package:flutter/services.dart';

import '../domain/compression_result.dart';
import '../domain/compression_settings.dart';
import '../domain/media_asset.dart';

class PlatformMediaService {
  static const _channel = MethodChannel('clever_media_compress/media');

  Future<CompressionResult> compressAndPublish(
    SelectedMedia media,
    CompressionSettings settings,
  ) async {
    try {
      final recipe = settings.recipeFor(media.kind);
      final response = await _channel
          .invokeMapMethod<String, dynamic>('compressAndPublish', {
            'sourceId': media.id,
            'sourcePath': media.path,
            'sourceName': media.name,
            'sourceUri': media.sourceUri,
            'sourceRelativePath': media.sourceRelativePath,
            'sourceCaptureMillis': media.sourceCaptureMillis,
            'mediaKind': media.kind.name,
            'quality': recipe.quality,
            'resolutionScale': recipe.resolutionScale,
            'preserveMetadata': settings.preserveMetadata,
            'preserveLocation': settings.preserveLocation,
            'outputSuffix': settings.outputSuffix,
          });

      if (response == null) {
        throw PlatformException(
          code: 'empty_response',
          message: 'The native media engine returned no result.',
        );
      }

      return CompressionResult(
        sourceId: media.id,
        status: response['success'] == true
            ? CompressionJobStatus.completed
            : CompressionJobStatus.failed,
        outputUri: response['outputUri'] as String?,
        outputName: response['outputName'] as String?,
        outputBytes: response['outputBytes'] as int?,
        captureDateVerified: response['captureDateVerified'] == true,
        message: response['message'] as String?,
      );
    } on PlatformException catch (error) {
      return CompressionResult(
        sourceId: media.id,
        status: CompressionJobStatus.failed,
        message: error.message ?? 'Native compression failed (${error.code}).',
      );
    } on MissingPluginException {
      return CompressionResult(
        sourceId: media.id,
        status: CompressionJobStatus.failed,
        message: 'The native media engine is unavailable on this platform.',
      );
    }
  }
}
