import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/media_picker_service.dart';
import '../data/platform_media_service.dart';
import '../data/preview_service.dart';
import '../domain/compression_result.dart';
import '../domain/compression_settings.dart';
import '../domain/media_asset.dart';

class CompressController extends ChangeNotifier {
  CompressController({
    required this.picker,
    required this.previewService,
    required this.platformService,
  });

  // Publicly named constructor inputs keep dependency wiring readable while the
  // private fields prevent platform services from leaking into the UI layer.
  final MediaPickerService picker;
  final PreviewService previewService;
  final PlatformMediaService platformService;

  final List<SelectedMedia> _media = [];
  final Map<String, CompressionResult> _results = {};
  CompressionSettings _settings = const CompressionSettings();
  PreviewSnapshot? _preview;
  Timer? _previewDebounce;
  int _previewGeneration = 0;
  bool _selecting = false;
  bool _previewing = false;
  bool _processing = false;
  String? _errorMessage;

  List<SelectedMedia> get media => List.unmodifiable(_media);
  Map<String, CompressionResult> get results => Map.unmodifiable(_results);
  CompressionSettings get settings => _settings;
  PreviewSnapshot? get preview => _preview;
  bool get selecting => _selecting;
  bool get previewing => _previewing;
  bool get processing => _processing;
  String? get errorMessage => _errorMessage;
  bool get hasMedia => _media.isNotEmpty;
  int get totalInputBytes => _media.fold(0, (sum, item) => sum + item.byteSize);
  SelectedMedia? get previewMedia {
    for (final item in _media) {
      if (item.isImage) return item;
    }
    return null;
  }

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
      final recovered = await picker.recoverLostMedia();
      if (recovered.isNotEmpty) {
        _media.addAll(recovered);
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
      final selected = await picker.pickMedia();
      if (selected.isNotEmpty) {
        _media
          ..clear()
          ..addAll(selected);
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
    final wasPreview = previewMedia?.id == id;
    _media.removeWhere((item) => item.id == id);
    _results.remove(id);
    if (wasPreview) {
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
    _preview = null;
    _errorMessage = null;
    notifyListeners();
  }

  void setQuality(double value) {
    _settings = _settings.copyWith(quality: value.round());
    notifyListeners();
    _schedulePreview();
  }

  void setResolutionScale(double value) {
    _settings = _settings.copyWith(resolutionScale: value);
    notifyListeners();
    _schedulePreview();
  }

  void setPreserveMetadata(bool value) {
    _settings = _settings.copyWith(preserveMetadata: value);
    if (!value) {
      _settings = _settings.copyWith(preserveLocation: false);
    }
    notifyListeners();
  }

  void setPreserveLocation(bool value) {
    if (!_settings.preserveMetadata) return;
    _settings = _settings.copyWith(preserveLocation: value);
    notifyListeners();
  }

  void dismissError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> startBatch() async {
    if (_media.isEmpty || _processing) return;
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
        messages.add(
          '$failures item${failures == 1 ? '' : 's'} could not be compressed',
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
    _previewDebounce = Timer(
      const Duration(milliseconds: 320),
      _generatePreview,
    );
  }

  Future<void> _generatePreview() async {
    final item = previewMedia;
    if (item == null) return;
    final generation = ++_previewGeneration;
    _previewing = true;
    notifyListeners();
    try {
      final result = await previewService.generate(item, _settings);
      if (generation == _previewGeneration) {
        _preview = result;
      }
    } catch (error) {
      if (generation == _previewGeneration) {
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
}
