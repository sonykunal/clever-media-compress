import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MagicIconBadge extends StatelessWidget {
  const MagicIconBadge({
    super.key,
    this.size = 44,
    this.iconSize = 22,
    this.inverted = false,
    this.icon = Icons.auto_fix_high_rounded,
  });

  final double size;
  final double iconSize;
  final bool inverted;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: inverted ? AppColors.ink : Colors.white,
        borderRadius: BorderRadius.circular(size * .32),
        border: Border.all(color: inverted ? AppColors.ink : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: .12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/branding/app_logo.png',
        fit: BoxFit.cover,
        semanticLabel: 'Clever Compress',
        errorBuilder: (context, error, stackTrace) => Icon(
          icon,
          size: iconSize,
          color: inverted ? AppColors.brandBright : AppColors.brand,
        ),
      ),
    );
  }
}

class MagicSparkle extends StatelessWidget {
  const MagicSparkle({super.key, this.size = 16, this.color = AppColors.brand});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.auto_awesome_rounded, size: size, color: color);
  }
}

class MagicTransformArtwork extends StatelessWidget {
  const MagicTransformArtwork({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 138,
      decoration: BoxDecoration(
        color: AppColors.violetMist,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.violetSoft),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _MagicTrailPainter()),
                ),
                const Positioned(
                  left: 15,
                  top: 13,
                  child: _MediaFileCard(
                    width: 94,
                    height: 108,
                    label: '12 MB',
                    large: true,
                  ),
                ),
                Positioned(
                  right: 18,
                  top: 37,
                  child: const _MediaFileCard(
                    width: 68,
                    height: 77,
                    label: '3.1 MB',
                  ),
                ),
                Positioned(
                  left: width * .48 - 22,
                  top: 47,
                  child: const MagicIconBadge(
                    size: 44,
                    iconSize: 21,
                    inverted: true,
                  ),
                ),
                const Positioned(
                  right: 88,
                  top: 14,
                  child: MagicSparkle(size: 17),
                ),
                const Positioned(
                  left: 119,
                  bottom: 14,
                  child: MagicSparkle(size: 12, color: AppColors.brandBright),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MediaFileCard extends StatelessWidget {
  const _MediaFileCard({
    required this.width,
    required this.height,
    required this.label,
    this.large = false,
  });

  final double width;
  final double height;
  final String label;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: large ? -.045 : .045,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: AppColors.ink, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withValues(alpha: .12),
              blurRadius: 15,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.violetSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Icon(
                    Icons.image_outlined,
                    color: AppColors.brandDark,
                    size: large ? 28 : 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: large ? 11 : 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MagicTrailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .33, size.height * .63)
      ..cubicTo(
        size.width * .47,
        size.height * .06,
        size.width * .67,
        size.height * .93,
        size.width * .79,
        size.height * .54,
      );
    final glow = Paint()
      ..color = AppColors.brand.withValues(alpha: .16)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final line = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.brandBright, AppColors.brandDark],
      ).createShader(Offset.zero & size)
      ..strokeWidth = 2.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(path, glow)
      ..drawPath(path, line);

    final dotPaint = Paint()..color = AppColors.brand;
    for (var index = 0; index < 6; index++) {
      final x = size.width * (.39 + index * .065);
      final y = size.height * (.28 + math.sin(index * 1.4) * .18);
      canvas.drawCircle(Offset(x, y), index.isEven ? 2.2 : 1.4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
