import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/media_asset.dart';

class MediaPickerService {
  MediaPickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  static const _nativeChannel = MethodChannel('clever_media_compress/media');

  Future<List<SelectedMedia>> pickMedia() async {
    if (Platform.isAndroid) {
      final response = await _nativeChannel.invokeListMethod<dynamic>(
        'pickMedia',
      );
      if (response == null) return const [];
      final nativeDetails = <String, Map<String, dynamic>>{};
      final files = <XFile>[];
      for (final item in response) {
        final details = Map<String, dynamic>.from(item as Map);
        final path = details['path'] as String;
        files.add(
          XFile(
            path,
            name: details['name'] as String?,
            mimeType: details['mimeType'] as String?,
          ),
        );
        nativeDetails[path] = details;
      }
      return _mapFiles(files, nativeDetails: nativeDetails);
    }

    final files = await _picker.pickMultipleMedia(
      requestFullMetadata: true,
      limit: 100,
    );
    return _mapFiles(files);
  }

  Future<List<SelectedMedia>> recoverLostMedia() async {
    final response = await _picker.retrieveLostData();
    if (response.isEmpty || response.files == null) return const [];
    return _mapFiles(response.files!);
  }

  Future<List<SelectedMedia>> _mapFiles(
    List<XFile> files, {
    Map<String, Map<String, dynamic>> nativeDetails = const {},
  }) async {
    final mapped = <SelectedMedia>[];
    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      final details = nativeDetails[file.path];
      final stat = await File(file.path).stat();
      final kind = _mediaKind(file);
      int? width;
      int? height;

      if (kind == MediaKind.image) {
        try {
          final bytes = await file.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          width = frame.image.width;
          height = frame.image.height;
          frame.image.dispose();
          codec.dispose();
        } catch (_) {
          // A selectable image can still be compressed natively even when the
          // Flutter preview codec does not support its source format.
        }
      }

      mapped.add(
        SelectedMedia(
          id: '${DateTime.now().microsecondsSinceEpoch}-$index-${file.name}',
          path: file.path,
          name: file.name,
          byteSize: stat.size,
          kind: kind,
          mimeType: file.mimeType,
          width: width,
          height: height,
          sourceUri: details?['sourceUri'] as String?,
          sourceRelativePath: details?['sourceRelativePath'] as String?,
          sourceCaptureMillis: details?['sourceCaptureMillis'] as int?,
        ),
      );
    }
    return mapped;
  }

  MediaKind _mediaKind(XFile file) {
    if (file.mimeType?.startsWith('video/') ?? false) return MediaKind.video;
    final extension = file.name.split('.').last.toLowerCase();
    const videoExtensions = {
      'mp4',
      'mov',
      'm4v',
      '3gp',
      '3g2',
      'mkv',
      'webm',
      'avi',
      'ts',
      'mts',
      'm2ts',
      'mpeg',
      'mpg',
      'vob',
      'wmv',
      'flv',
    };
    return videoExtensions.contains(extension)
        ? MediaKind.video
        : MediaKind.image;
  }
}
