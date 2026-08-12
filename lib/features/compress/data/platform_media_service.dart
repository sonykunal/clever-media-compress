import 'package:flutter/services.dart';

import '../domain/compression_result.dart';
import '../domain/compression_settings.dart';
import '../domain/media_asset.dart';
import '../domain/reclaim_result.dart';

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
            'sourceAssetIdentifier': media.sourceAssetIdentifier,
            'sourceAlbumIdentifiers': media.sourceAlbumIdentifiers,
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

  Future<ReclaimResult> reclaimOriginals(List<SelectedMedia> media) async {
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'reclaimOriginals',
        {
          'items': media
              .map(
                (item) => {
                  'sourceAssetIdentifier': item.sourceAssetIdentifier,
                  'sourceName': item.name,
                  'sourceBytes': item.byteSize,
                },
              )
              .toList(growable: false),
        },
      );
      if (response == null) {
        throw PlatformException(
          code: 'empty_reclaim_response',
          message: 'The system returned no storage-reclaim result.',
        );
      }
      return ReclaimResult(
        success: response['success'] == true,
        reclaimedCount: response['reclaimedCount'] as int? ?? 0,
        reclaimedBytes: response['reclaimedBytes'] as int? ?? 0,
        message:
            response['message'] as String? ??
            'The original-media request finished.',
      );
    } on PlatformException catch (error) {
      return ReclaimResult(
        success: false,
        reclaimedCount: 0,
        reclaimedBytes: 0,
        message: error.message ?? 'The originals could not be reclaimed.',
      );
    } on MissingPluginException {
      return const ReclaimResult(
        success: false,
        reclaimedCount: 0,
        reclaimedBytes: 0,
        message: 'Storage reclaim is unavailable on this platform build.',
      );
    } catch (_) {
      return const ReclaimResult(
        success: false,
        reclaimedCount: 0,
        reclaimedBytes: 0,
        message: 'The system returned an invalid storage-reclaim result.',
      );
    }
  }
}
