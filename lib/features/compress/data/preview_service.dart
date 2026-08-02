import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../domain/compression_settings.dart';
import '../domain/media_asset.dart';

class PreviewSnapshot {
  const PreviewSnapshot({
    required this.bytes,
    required this.byteSize,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int byteSize;
  final int width;
  final int height;
}

class PreviewService {
  Future<PreviewSnapshot> generate(
    SelectedMedia media,
    CompressionSettings settings,
  ) async {
    if (!media.isImage) {
      throw const FormatException('Live preview is available for images.');
    }

    final sourceWidth = media.width ?? 2400;
    final sourceHeight = media.height ?? 1800;
    final targetWidth = (sourceWidth * settings.resolutionScale).round();
    final targetHeight = (sourceHeight * settings.resolutionScale).round();
    final bytes = await FlutterImageCompress.compressWithFile(
      media.path,
      minWidth: targetWidth.clamp(1, sourceWidth).toInt(),
      minHeight: targetHeight.clamp(1, sourceHeight).toInt(),
      quality: settings.quality,
      autoCorrectionAngle: true,
      keepExif: false,
      format: CompressFormat.jpeg,
    );

    if (bytes == null || bytes.isEmpty) {
      throw StateError('This image format could not be previewed.');
    }

    return PreviewSnapshot(
      bytes: bytes,
      byteSize: bytes.length,
      width: targetWidth,
      height: targetHeight,
    );
  }
}
