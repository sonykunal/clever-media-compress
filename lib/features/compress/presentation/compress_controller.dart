import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/media_picker_service.dart';
import '../data/media_permission_service.dart';
import '../data/platform_media_service.dart';
import '../data/preview_service.dart';
import '../domain/compression_result.dart';
import '../domain/compression_settings.dart';
import '../domain/media_asset.dart';

class CompressController extends ChangeNotifier {
  CompressController({
    required this.picker,
    required this.permissionService,
    required this.previewService,
    required this.platformService,
  });

  // Publicly named constructor inputs keep dependency wiring readable while the
  // private fields prevent platform services from leaking into the UI layer.
  final MediaPickerService picker;
  final MediaPermissionService permissionService;
  final PreviewService previewService;
  final PlatformMediaService platformService;

  final List<SelectedMedia> _media = [];
  final Map<String, CompressionResult> _results = {};
  CompressionSettings _settings = const CompressionSettings();
  PreviewSnapshot? _preview;
  String? _previewMediaId;
  Timer? _previewDebounce;
  int _previewGeneration = 0;
  bool _selecting = false;
  bool _previewing = false;
  bool _processing = false;
  String? _errorMessage;
  String? _permissionMessage;
  bool _canOpenPermissionSettings = false;

  List<SelectedMedia> get media => List.unmodifiable(_media);
  Map<String, CompressionResult> get results => Map.unmodifiable(_results);
  CompressionSettings get settings => _settings;
  PreviewSnapshot? get preview => _preview;
  bool get selecting => _selecting;
  bool get previewing => _previewing;
  bool get processing => _processing;
  String? get errorMessage => _errorMessage;
  String? get permissionMessage => _permissionMessage;
  bool get canOpenPermissionSettings => _canOpenPermissionSettings;
  bool get hasMedia => _media.isNotEmpty;
  int get totalInputBytes => _media.fold(0, (sum, item) => sum + item.byteSize);
  SelectedMedia? get previewMedia {
    final selected = _mediaById(_previewMediaId);
    if (selected != null) return selected;
    return _media.isEmpty ? null : _media.first;
  }

  bool get hasCompletedBatch =>
      _media.isNotEmpty &&
      _results.length == _media.length &&
      _results.values.every(
        (item) =>
            item.status == CompressionJobStatus.completed ||
            item.status == CompressionJobStatus.failed,
      );

  bool get canStartBatch =>
      _media.isNotEmpty && !_processing && !hasCompletedBatch;

  double get progress {
    if (_media.isEmpty) return 0;
    final finished = _results.values
        .where(
          (item) =>
              item.status == CompressionJobStatus.completed ||
              item.status == CompressionJobStatus.failed,
        )
        .length;
    return finished / _media.length;
  }

  Future<void> initialize() async {
    try {
      await requestFullMediaAccess(silentWhenFull: true);
      final recovered = await picker.recoverLostMedia();
      if (recovered.isNotEmpty) {
        _media.addAll(recovered);
        _previewMediaId = _firstMediaId(recovered);
        notifyListeners();
        await _generatePreview();
      }
    } catch (_) {
      // Lost-data recovery is opportunistic and should not block app startup.
    }
  }

  Future<void> selectMedia() async {
    if (_selecting || _processing) return;
    _selecting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final access = await requestFullMediaAccess(silentWhenFull: true);
      if (!access.hasFullAccess &&
          access.status != MediaAccessStatus.unavailable &&
          access.canOpenSettings) {
        _selecting = false;
        notifyListeners();
        return;
      }
      final selected = await picker.pickMedia();
      if (selected.isNotEmpty) {
        _media
          ..clear()
          ..addAll(selected);
        _previewMediaId = _firstMediaId(selected);
        _results.clear();
        _preview = null;
        notifyListeners();
        await _generatePreview();
      }
    } catch (error) {
      _errorMessage = 'Could not open your media library. $error';
    } finally {
      _selecting = false;
      notifyListeners();
    }
  }

  void removeMedia(String id) {
    if (_processing) return;
    _media.removeWhere((item) => item.id == id);
    _results.remove(id);
    if (_previewMediaId == id || previewMedia == null) {
      _previewMediaId = _firstMediaId(_media);
      _preview = null;
      _schedulePreview();
    }
    notifyListeners();
  }

  void clearMedia() {
    if (_processing) return;
    _previewDebounce?.cancel();
    _media.clear();
    _results.clear();
    _previewMediaId = null;
    _preview = null;
    _previewGeneration++;
    _errorMessage = null;
    notifyListeners();
  }

  int get imageCount => _media.where((media) => media.isImage).length;
  int get videoCount => _media.where((media) => !media.isImage).length;

  void setImageQuality(double value) {
    _discardCompletedResults();
    _settings = _settings.copyWith(
      image: _settings.image.copyWith(quality: value.round()),
    );
    notifyListeners();
    _schedulePreview();
  }

  void setImageResolutionScale(double value) {
    _discardCompletedResults();
    _settings = _settings.copyWith(
      image: _settings.image.copyWith(resolutionScale: value),
    );
    notifyListeners();
    _schedulePreview();
  }

  void setVideoQuality(double value) {
    _discardCompletedResults();
    _settings = _settings.copyWith(
      video: _settings.video.copyWith(quality: value.round()),
    );
    notifyListeners();
  }

  void setVideoResolutionScale(double value) {
    _discardCompletedResults();
    _settings = _settings.copyWith(
      video: _settings.video.copyWith(resolutionScale: value),
    );
    notifyListeners();
  }

  void setPreserveMetadata(bool value) {
    _discardCompletedResults();
    _settings = _settings.copyWith(preserveMetadata: value);
    if (!value) {
      _settings = _settings.copyWith(preserveLocation: false);
    }
    notifyListeners();
  }

  void setPreserveLocation(bool value) {
    if (!_settings.preserveMetadata) return;
    _discardCompletedResults();
    _settings = _settings.copyWith(preserveLocation: value);
    notifyListeners();
  }

  void selectPreviewMedia(String id) {
    if (_processing) return;
    final selected = _mediaById(id);
    if (selected == null || _previewMediaId == id) return;
    _previewGeneration++;
    _previewMediaId = id;
    _preview = null;
    notifyListeners();
    if (selected.isImage) {
      _generatePreview();
    } else {
      _previewDebounce?.cancel();
      _previewing = false;
      notifyListeners();
    }
  }

  void dismissError() {
    _errorMessage = null;
    notifyListeners();
  }

  void dismissPermissionMessage() {
    _permissionMessage = null;
    notifyListeners();
  }

  Future<MediaAccessResult> requestFullMediaAccess({
    bool silentWhenFull = false,
  }) async {
    final access = await permissionService.requestFullAccess();
    if (access.hasFullAccess ||
        access.status == MediaAccessStatus.unavailable) {
      _permissionMessage = null;
      _canOpenPermissionSettings = false;
    } else {
      _permissionMessage = access.message;
      _canOpenPermissionSettings = access.canOpenSettings;
    }
    if (!silentWhenFull || !access.hasFullAccess) notifyListeners();
    return access;
  }

  Future<void> openPermissionSettings() async {
    await permissionService.openSettings();
  }

  Future<void> startBatch() async {
    if (!canStartBatch) return;
    _processing = true;
    _errorMessage = null;
    _results.clear();
    for (final item in _media) {
      _results[item.id] = CompressionResult(
        sourceId: item.id,
        status: CompressionJobStatus.waiting,
      );
    }
    notifyListeners();

    for (final item in _media) {
      _results[item.id] = _results[item.id]!.copyWith(
        status: CompressionJobStatus.processing,
      );
      notifyListeners();
      _results[item.id] = await platformService.compressAndPublish(
        item,
        _settings,
      );
      notifyListeners();
    }

    _processing = false;
    final failures = _results.values
        .where((item) => item.status == CompressionJobStatus.failed)
        .length;
    final unverified = _results.values
        .where(
          (item) =>
              item.status == CompressionJobStatus.completed &&
              !item.captureDateVerified,
        )
        .length;
    if (failures > 0 || unverified > 0) {
      final messages = <String>[];
      if (failures > 0) {
        final firstFailure = _media
            .map((media) => (media, result: _results[media.id]))
            .where(
              (entry) => entry.result?.status == CompressionJobStatus.failed,
            )
            .first;
        final reason = firstFailure.result?.message ?? 'Unknown native error';
        messages.add(
          failures == 1
              ? '${firstFailure.$1.name} could not be compressed: $reason'
              : '$failures items could not be compressed. First error: '
                    '${firstFailure.$1.name}: $reason',
        );
      }
      if (unverified > 0) {
        messages.add(
          '$unverified item${unverified == 1 ? '' : 's'} had no verifiable capture date',
        );
      }
      _errorMessage = '${messages.join('. ')}.';
    }
    notifyListeners();
  }

  void _schedulePreview() {
    _previewDebounce?.cancel();
    if (previewMedia?.isImage != true) {
      _previewGeneration++;
      _previewing = false;
      return;
    }
    _previewDebounce = Timer(
      const Duration(milliseconds: 320),
      _generatePreview,
    );
  }

  Future<void> _generatePreview() async {
    final item = previewMedia;
    if (item == null || !item.isImage) {
      _preview = null;
      _previewing = false;
      return;
    }
    final generation = ++_previewGeneration;
    _previewing = true;
    notifyListeners();
    try {
      final result = await previewService.generate(item, _settings.image);
      if (generation == _previewGeneration && previewMedia?.id == item.id) {
        _preview = result;
      }
    } catch (error) {
      if (generation == _previewGeneration && previewMedia?.id == item.id) {
        _preview = null;
        _errorMessage = 'A live preview is unavailable for ${item.name}.';
      }
    } finally {
      if (generation == _previewGeneration) {
        _previewing = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    super.dispose();
  }

  SelectedMedia? _mediaById(String? id) {
    if (id == null) return null;
    for (final item in _media) {
      if (item.id == id) return item;
    }
    return null;
  }

  String? _firstMediaId(Iterable<SelectedMedia> items) {
    for (final item in items) {
      return item.id;
    }
    return null;
  }

  void _discardCompletedResults() {
    if (_results.isEmpty || _processing) return;
    _results.clear();
    _errorMessage = null;
  }
}
