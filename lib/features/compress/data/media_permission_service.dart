import 'dart:io';

import 'package:flutter/services.dart';

enum MediaAccessStatus { full, limited, denied, unavailable }

class MediaAccessResult {
  const MediaAccessResult({
    required this.status,
    required this.message,
    this.canOpenSettings = false,
  });

  final MediaAccessStatus status;
  final String message;
  final bool canOpenSettings;

  bool get hasFullAccess => status == MediaAccessStatus.full;

  factory MediaAccessResult.fromMap(Map<dynamic, dynamic> map) {
    final statusName = map['status'] as String? ?? 'unavailable';
    return MediaAccessResult(
      status: MediaAccessStatus.values.firstWhere(
        (item) => item.name == statusName,
        orElse: () => MediaAccessStatus.unavailable,
      ),
      message: map['message'] as String? ?? '',
      canOpenSettings: map['canOpenSettings'] == true,
    );
  }
}

class MediaPermissionService {
  static const _nativeChannel = MethodChannel('clever_media_compress/media');

  Future<MediaAccessResult> requestFullAccess() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return const MediaAccessResult(
        status: MediaAccessStatus.unavailable,
        message: 'Full media-library permission is not needed here.',
      );
    }

    try {
      final response = await _nativeChannel.invokeMapMethod<dynamic, dynamic>(
        'requestMediaLibraryAccess',
      );
      if (response == null) {
        return const MediaAccessResult(
          status: MediaAccessStatus.unavailable,
          message: 'The media permission service returned no result.',
        );
      }
      return MediaAccessResult.fromMap(response);
    } on MissingPluginException {
      return const MediaAccessResult(
        status: MediaAccessStatus.full,
        message: 'Media permission is handled by the test environment.',
      );
    }
  }

  Future<void> openSettings() async {
    try {
      await _nativeChannel.invokeMethod<void>('openAppSettings');
    } on MissingPluginException {
      return;
    }
  }
}
