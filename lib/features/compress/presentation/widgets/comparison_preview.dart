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
  double _split = .5;

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    final savedPercent = preview == null || widget.media.byteSize == 0
        ? null
        : ((1 - preview.byteSize / widget.media.byteSize) * 100)
              .clamp(0, 99)
              .round();

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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live comparison',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Drag to compare before and after',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
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
                      final width = constraints.maxWidth;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            _split = (details.localPosition.dx / width).clamp(
                              .05,
                              .95,
                            );
                          });
                        },
                        onTapDown: (details) {
                          setState(() {
                            _split = (details.localPosition.dx / width).clamp(
                              .05,
                              .95,
                            );
                          });
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Color(0xFF161622)),
                            if (preview != null)
                              Image.memory(
                                preview.bytes,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              )
                            else
                              Image.file(
                                File(widget.media.path),
                                fit: BoxFit.cover,
                              ),
                            ClipRect(
                              clipper: _WidthClipper(_split),
                              child: Image.file(
                                File(widget.media.path),
                                fit: BoxFit.cover,
                              ),
                            ),
                            const Positioned(
                              left: 12,
                              top: 12,
                              child: _PreviewLabel(text: 'ORIGINAL'),
                            ),
                            const Positioned(
                              right: 12,
                              top: 12,
                              child: _PreviewLabel(text: 'COMPRESSED'),
                            ),
                            Positioned(
                              left: width * _split - 1,
                              top: 0,
                              bottom: 0,
                              child: Container(width: 2, color: Colors.white),
                            ),
                            Positioned(
                              left: width * _split - 19,
                              top: constraints.maxHeight / 2 - 19,
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.ink,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.brand.withValues(
                                        alpha: .28,
                                      ),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.auto_fix_high_rounded,
                                  size: 19,
                                  color: AppColors.brandBright,
                                ),
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
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.violetMist,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.violetSoft),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SizeMetric(
                      label: 'Original',
                      value: Formatters.fileSize(widget.media.byteSize),
                    ),
                  ),
                  const Icon(
                    Icons.auto_fix_high_rounded,
                    color: AppColors.brand,
                    size: 17,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SizeMetric(
                      label: 'Estimated output',
                      value: preview == null
                          ? 'Calculating…'
                          : Formatters.fileSize(preview.byteSize),
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
  const _PreviewLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xA6000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: .7,
        ),
      ),
    );
  }
}

class _SizeMetric extends StatelessWidget {
  const _SizeMetric({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
