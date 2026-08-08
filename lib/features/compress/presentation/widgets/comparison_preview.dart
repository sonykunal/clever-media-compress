import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/magic_accents.dart';
import '../../data/preview_service.dart';
import '../../domain/media_asset.dart';

class ComparisonPreview extends StatefulWidget {
  const ComparisonPreview({
    super.key,
    required this.media,
    required this.preview,
    required this.loading,
    this.onScrollLockChanged,
  });

  final SelectedMedia media;
  final PreviewSnapshot? preview;
  final bool loading;
  final ValueChanged<bool>? onScrollLockChanged;

  @override
  State<ComparisonPreview> createState() => _ComparisonPreviewState();
}

class _ComparisonPreviewState extends State<ComparisonPreview>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late final AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;
  double _split = .5;
  double _zoom = 1;
  Size _viewport = Size.zero;

  @override
  void initState() {
    super.initState();
    _zoomAnimationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
        )..addListener(() {
          final next = _zoomAnimation?.value;
          if (next != null) _transformationController.value = next;
        });
    _transformationController.addListener(_syncZoom);
  }

  @override
  void didUpdateWidget(covariant ComparisonPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.id != widget.media.id) {
      _split = .5;
      _jumpToIdentity();
    }
  }

  @override
  void dispose() {
    _transformationController
      ..removeListener(_syncZoom)
      ..dispose();
    widget.onScrollLockChanged?.call(false);
    _zoomAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    final savedPercent = preview == null || widget.media.byteSize == 0
        ? null
        : ((1 - preview.byteSize / widget.media.byteSize) * 100)
              .clamp(0, 99)
              .round();
    final originalSize = Formatters.fileSize(widget.media.byteSize);
    final estimatedSize = preview == null
        ? 'Calculating...'
        : Formatters.fileSize(preview.byteSize);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const MagicIconBadge(size: 40, iconSize: 20),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live comparison',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Previewing ${widget.media.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (savedPercent != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.violetMist,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.violetSoft),
                    ),
                    child: Text(
                      '$savedPercent% smaller',
                      style: const TextStyle(
                        color: AppColors.brandDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final viewport = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      _viewport = viewport;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: Color(0xFF161622)),
                          _ZoomableImageLayer(
                            viewport: viewport,
                            controller: _transformationController,
                            onInteractionStart: _zoomAnimationController.stop,
                            onScrollLockChanged: widget.onScrollLockChanged,
                            child: preview != null
                                ? Image.memory(
                                    preview.bytes,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                  )
                                : Image.file(
                                    File(widget.media.path),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          ClipRect(
                            clipper: _WidthClipper(_split),
                            child: IgnorePointer(
                              child: _MirroredImageLayer(
                                viewport: viewport,
                                controller: _transformationController,
                                child: preview != null
                                    ? Image.file(
                                        File(widget.media.path),
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        File(widget.media.path),
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            top: 12,
                            child: _PreviewLabel(
                              title: 'ORIGINAL',
                              size: originalSize,
                            ),
                          ),
                          Positioned(
                            right: 12,
                            top: 12,
                            child: _PreviewLabel(
                              title: 'COMPRESSED',
                              size: estimatedSize,
                            ),
                          ),
                          Positioned(
                            left: 12,
                            bottom: 12,
                            child: _InlineZoomControls(
                              zoom: _zoom,
                              onZoomOut: _zoom <= 1.01
                                  ? null
                                  : () => _animateToZoom(_zoom - .4),
                              onZoomIn: _zoom >= 4.99
                                  ? null
                                  : () => _animateToZoom(_zoom + .4),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: _InlineResetButton(
                              enabled: _zoom > 1.01,
                              onPressed: () => _animateToZoom(1),
                            ),
                          ),
                          Positioned(
                            left: constraints.maxWidth * _split - 7,
                            top: 0,
                            bottom: 0,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragUpdate: (details) {
                                _setSplit(
                                  constraints.maxWidth * _split +
                                      details.delta.dx,
                                  viewport,
                                );
                              },
                              child: const SizedBox(
                                width: 14,
                                child: Center(
                                  child: VerticalDivider(
                                    width: 2,
                                    thickness: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: constraints.maxWidth * _split - 19,
                            top: constraints.maxHeight / 2 - 19,
                            child: const IgnorePointer(child: _DividerHandle()),
                          ),
                          if (widget.loading)
                            ColoredBox(
                              color: Colors.black.withValues(alpha: .35),
                              child: const Center(
                                child: SizedBox.square(
                                  dimension: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setSplit(double localDx, Size viewport) {
    setState(() {
      _split = (localDx / viewport.width).clamp(.05, .95);
    });
  }

  void _jumpToIdentity() {
    _zoomAnimationController.stop();
    _transformationController.value = Matrix4.identity();
    if (mounted) setState(() => _zoom = 1);
  }

  void _animateToZoom(double value) {
    final targetZoom = value.clamp(1.0, 5.0);
    final begin = Matrix4.copy(_transformationController.value);
    final end = targetZoom <= 1.01
        ? Matrix4.identity()
        : _matrixForZoom(targetZoom);
    _zoomAnimation = Matrix4Tween(begin: begin, end: end).animate(
      CurvedAnimation(
        parent: _zoomAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _zoomAnimationController
      ..reset()
      ..forward();
  }

  Matrix4 _matrixForZoom(double zoom) {
    if (_viewport == Size.zero) {
      return Matrix4.identity()..scaleByDouble(zoom, zoom, zoom, 1);
    }

    final current = _transformationController.value;
    final currentScale = current.getMaxScaleOnAxis().clamp(1.0, 5.0);
    final currentTranslation = Offset(current.storage[12], current.storage[13]);
    final focalPoint = Offset(_viewport.width / 2, _viewport.height / 2);
    final contentFocal = (focalPoint - currentTranslation) / currentScale;
    final unclampedTranslation = focalPoint - contentFocal * zoom;
    final clampedTranslation = _clampTranslation(unclampedTranslation, zoom);

    return Matrix4.identity()
      ..translateByDouble(clampedTranslation.dx, clampedTranslation.dy, 0, 1)
      ..scaleByDouble(zoom, zoom, zoom, 1);
  }

  Offset _clampTranslation(Offset translation, double zoom) {
    if (_viewport == Size.zero || zoom <= 1.01) return Offset.zero;

    final minX = _viewport.width * (1 - zoom);
    final minY = _viewport.height * (1 - zoom);
    return Offset(
      translation.dx.clamp(minX, 0.0),
      translation.dy.clamp(minY, 0.0),
    );
  }

  void _syncZoom() {
    final scale = _transformationController.value.getMaxScaleOnAxis().clamp(
      1.0,
      5.0,
    );
    if (!mounted || (scale - _zoom).abs() < .02) return;
    setState(() => _zoom = scale);
  }
}

class _ZoomableImageLayer extends StatelessWidget {
  const _ZoomableImageLayer({
    required this.viewport,
    required this.controller,
    required this.child,
    required this.onInteractionStart,
    this.onScrollLockChanged,
  });

  final Size viewport;
  final TransformationController controller;
  final Widget child;
  final VoidCallback onInteractionStart;
  final ValueChanged<bool>? onScrollLockChanged;

  @override
  Widget build(BuildContext context) {
    return _CustomZoomLayer(
      viewport: viewport,
      controller: controller,
      onInteractionStart: onInteractionStart,
      onScrollLockChanged: onScrollLockChanged,
      child: child,
    );
  }
}

class _CustomZoomLayer extends StatefulWidget {
  const _CustomZoomLayer({
    required this.viewport,
    required this.controller,
    required this.child,
    required this.onInteractionStart,
    this.onScrollLockChanged,
  });

  final Size viewport;
  final TransformationController controller;
  final Widget child;
  final VoidCallback onInteractionStart;
  final ValueChanged<bool>? onScrollLockChanged;

  @override
  State<_CustomZoomLayer> createState() => _CustomZoomLayerState();
}

class _CustomZoomLayerState extends State<_CustomZoomLayer> {
  final Map<int, Offset> _pointers = {};
  Matrix4 _startMatrix = Matrix4.identity();
  double _startScale = 1;
  Offset _startTranslation = Offset.zero;
  Offset _startFocalPoint = Offset.zero;
  double _startPointerDistance = 1;
  bool _pinching = false;
  int? _panPointer;
  Offset? _lastPanPoint;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        _PreviewGestureClaimRecognizer:
            GestureRecognizerFactoryWithHandlers<
              _PreviewGestureClaimRecognizer
            >(
              () => _PreviewGestureClaimRecognizer(
                shouldClaimSinglePointer: () =>
                    _scaleOf(widget.controller.value) > 1.01,
              ),
              (_PreviewGestureClaimRecognizer instance) {},
            ),
      },
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, child) {
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _handlePointerDown,
            onPointerMove: _handlePointerMove,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerUp,
            child: ClipRect(
              child: Transform(
                transform: widget.controller.value,
                alignment: Alignment.topLeft,
                child: child,
              ),
            ),
          );
        },
        child: SizedBox(
          width: widget.viewport.width,
          height: widget.viewport.height,
          child: widget.child,
        ),
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    widget.onInteractionStart();
    _updateScrollLock();

    if (_pointers.length >= 2) {
      _beginPinch();
      return;
    }

    if (_scaleOf(widget.controller.value) > 1.01) {
      _panPointer = event.pointer;
      _lastPanPoint = event.localPosition;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;
    _updateScrollLock();

    if (_pointers.length >= 2) {
      if (!_pinching) _beginPinch();
      _updatePinch();
      return;
    }

    if (_panPointer == event.pointer &&
        _scaleOf(widget.controller.value) > 1.01) {
      _updatePan(event.localPosition);
    }
  }

  void _handlePointerUp(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length >= 2) {
      _beginPinch();
      _updateScrollLock();
      return;
    }

    _pinching = false;
    _panPointer = _pointers.keys.firstOrNull;
    _lastPanPoint = _panPointer == null ? null : _pointers[_panPointer];

    if (_scaleOf(widget.controller.value) < 1.02) {
      widget.controller.value = Matrix4.identity();
    }
    _updateScrollLock();
  }

  void _beginPinch() {
    final points = _firstTwoPointerPositions();
    if (points == null) return;
    widget.onInteractionStart();
    _startMatrix = Matrix4.copy(widget.controller.value);
    _startScale = _scaleOf(_startMatrix);
    _startTranslation = _translationOf(_startMatrix);
    _startFocalPoint = (points.$1 + points.$2) / 2;
    _startPointerDistance = (points.$1 - points.$2).distance.clamp(
      1.0,
      double.infinity,
    );
    _pinching = true;
    _panPointer = null;
    _lastPanPoint = null;
    _updateScrollLock();
  }

  void _updatePinch() {
    final points = _firstTwoPointerPositions();
    if (points == null) return;

    final distance = (points.$1 - points.$2).distance.clamp(
      1.0,
      double.infinity,
    );
    final focalPoint = (points.$1 + points.$2) / 2;
    final nextScale = (_startScale * distance / _startPointerDistance).clamp(
      1.0,
      5.0,
    );
    if (nextScale <= 1.01) {
      widget.controller.value = Matrix4.identity();
      return;
    }

    final contentFocalPoint =
        (_startFocalPoint - _startTranslation) / _startScale;
    final unclampedTranslation = focalPoint - contentFocalPoint * nextScale;
    final translation = _clampTranslation(unclampedTranslation, nextScale);

    widget.controller.value = Matrix4.identity()
      ..translateByDouble(translation.dx, translation.dy, 0, 1)
      ..scaleByDouble(nextScale, nextScale, nextScale, 1);
  }

  void _updatePan(Offset point) {
    final lastPoint = _lastPanPoint;
    if (lastPoint == null) {
      _lastPanPoint = point;
      return;
    }

    final matrix = widget.controller.value;
    final scale = _scaleOf(matrix);
    final currentTranslation = _translationOf(matrix);
    final translation = _clampTranslation(
      currentTranslation + point - lastPoint,
      scale,
    );
    widget.controller.value = Matrix4.identity()
      ..translateByDouble(translation.dx, translation.dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
    _lastPanPoint = point;
  }

  (Offset, Offset)? _firstTwoPointerPositions() {
    if (_pointers.length < 2) return null;
    final values = _pointers.values.take(2).toList(growable: false);
    return (values[0], values[1]);
  }

  double _scaleOf(Matrix4 matrix) => matrix.getMaxScaleOnAxis().clamp(1.0, 5.0);

  Offset _translationOf(Matrix4 matrix) =>
      Offset(matrix.storage[12], matrix.storage[13]);

  Offset _clampTranslation(Offset translation, double zoom) {
    final viewport = widget.viewport;
    if (viewport == Size.zero || zoom <= 1.01) return Offset.zero;

    final minX = viewport.width * (1 - zoom);
    final minY = viewport.height * (1 - zoom);
    return Offset(
      translation.dx.clamp(minX, 0.0),
      translation.dy.clamp(minY, 0.0),
    );
  }

  void _updateScrollLock() {
    final shouldLock =
        _pointers.isNotEmpty &&
        (_pointers.length >= 2 || _scaleOf(widget.controller.value) > 1.01);
    widget.onScrollLockChanged?.call(shouldLock);
  }
}

class _PreviewGestureClaimRecognizer extends OneSequenceGestureRecognizer {
  _PreviewGestureClaimRecognizer({required this.shouldClaimSinglePointer});

  final bool Function() shouldClaimSinglePointer;
  final Set<int> _trackedPointers = {};

  @override
  String get debugDescription => 'preview gesture claim';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _trackedPointers.add(event.pointer);
    if (shouldClaimSinglePointer() || _trackedPointers.length >= 2) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _trackedPointers.remove(event.pointer);
      stopTrackingPointer(event.pointer);
    } else if (_trackedPointers.length >= 2) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    stopTrackingPointer(pointer);
    _trackedPointers.remove(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _trackedPointers.clear();
  }
}

class _MirroredImageLayer extends StatelessWidget {
  const _MirroredImageLayer({
    required this.viewport,
    required this.controller,
    required this.child,
  });

  final Size viewport;
  final TransformationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return ClipRect(
          child: Transform(
            transform: controller.value,
            alignment: Alignment.topLeft,
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: viewport.width,
        height: viewport.height,
        child: child,
      ),
    );
  }
}

class _DividerHandle extends StatelessWidget {
  const _DividerHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: .28),
            blurRadius: 12,
          ),
        ],
      ),
      child: const Icon(
        Icons.auto_fix_high_rounded,
        size: 19,
        color: AppColors.brandBright,
      ),
    );
  }
}

class _WidthClipper extends CustomClipper<Rect> {
  const _WidthClipper(this.factor);

  final double factor;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * factor, size.height);

  @override
  bool shouldReclip(_WidthClipper oldClipper) => oldClipper.factor != factor;
}

class _PreviewLabel extends StatelessWidget {
  const _PreviewLabel({required this.title, required this.size});

  final String title;
  final String size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xB3FFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x80FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            size,
            style: const TextStyle(
              color: AppColors.brandDark,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineZoomControls extends StatelessWidget {
  const _InlineZoomControls({
    required this.zoom,
    required this.onZoomOut,
    required this.onZoomIn,
  });

  final double zoom;
  final VoidCallback? onZoomOut;
  final VoidCallback? onZoomIn;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OverlayIconButton(
          tooltip: 'Zoom out',
          icon: Icons.remove_rounded,
          onPressed: onZoomOut,
        ),
        const SizedBox(width: 6),
        _OverlayIconButton(
          tooltip: 'Zoom in',
          icon: Icons.add_rounded,
          onPressed: onZoomIn,
        ),
      ],
    );
  }
}

class _InlineResetButton extends StatelessWidget {
  const _InlineResetButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brandDark,
        disabledForegroundColor: AppColors.muted.withValues(alpha: .65),
        backgroundColor: const Color(0xB3FFFFFF),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      icon: const Icon(Icons.center_focus_strong_outlined, size: 13),
      label: const Text(
        'Reset',
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 15,
      color: AppColors.brandDark,
      disabledColor: AppColors.muted.withValues(alpha: .55),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xB3FFFFFF),
        minimumSize: const Size.square(28),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
