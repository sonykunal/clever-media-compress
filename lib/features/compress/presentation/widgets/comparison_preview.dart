import 'dart:io';

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
  });

  final SelectedMedia media;
  final PreviewSnapshot? preview;
  final bool loading;

  @override
  State<ComparisonPreview> createState() => _ComparisonPreviewState();
}

class _ComparisonPreviewState extends State<ComparisonPreview> {
  final TransformationController _transformationController =
      TransformationController();
  double _split = .5;
  double _zoom = 1;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_syncZoom);
  }

  @override
  void didUpdateWidget(covariant ComparisonPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.id != widget.media.id) {
      _split = .5;
      _setZoom(1);
    }
  }

  @override
  void dispose() {
    _transformationController
      ..removeListener(_syncZoom)
      ..dispose();
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
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: Color(0xFF161622)),
                          _ZoomableImageLayer(
                            viewport: viewport,
                            controller: _transformationController,
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
                              child: _ZoomableImageLayer(
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
                                  : () => _setZoom(_zoom - .5),
                              onZoomIn: _zoom >= 4.99
                                  ? null
                                  : () => _setZoom(_zoom + .5),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: _InlineResetButton(
                              enabled: _zoom > 1.01,
                              onPressed: () => _setZoom(1),
                            ),
                          ),
                          Positioned(
                            left: constraints.maxWidth * _split - 18,
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
                                width: 36,
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
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragUpdate: (details) {
                                _setSplit(
                                  constraints.maxWidth * _split +
                                      details.delta.dx,
                                  viewport,
                                );
                              },
                              child: const _DividerHandle(),
                            ),
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

  void _setZoom(double value) {
    final next = value.clamp(1.0, 5.0);
    _transformationController.value = Matrix4.identity()
      ..scaleByDouble(next, next, next, 1);
    if (mounted) setState(() => _zoom = next);
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
  });

  final Size viewport;
  final TransformationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: controller,
      minScale: 1,
      maxScale: 5,
      panEnabled: true,
      scaleEnabled: true,
      boundaryMargin: EdgeInsets.zero,
      clipBehavior: Clip.hardEdge,
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
