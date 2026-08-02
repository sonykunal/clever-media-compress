import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class HeroPanel extends StatelessWidget {
  const HeroPanel({
    super.key,
    required this.hasMedia,
    required this.selecting,
    required this.onSelect,
  });

  final bool hasMedia;
  final bool selecting;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF28205F), Color(0xFF5B4FE5), Color(0xFF478CEB)],
          stops: [0, .62, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: .22),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -34,
            top: -58,
            child: _GlowOrb(size: 170, color: Color(0x4035E8CF)),
          ),
          const Positioned(
            right: 78,
            bottom: -72,
            child: _GlowOrb(size: 140, color: Color(0x3060A5FA)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .16),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 16,
                      color: Color(0xFF8FF3D8),
                    ),
                    SizedBox(width: 7),
                    Text(
                      'CHRONOLOGY SAFE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Smaller media.\nSame moment.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 35,
                  height: 1.03,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                'Compress a whole batch while keeping the capture date that your gallery uses for sorting.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .76),
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: selecting ? null : onSelect,
                icon: selecting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brandDark,
                        ),
                      )
                    : Icon(
                        hasMedia
                            ? Icons.add_photo_alternate_outlined
                            : Icons.photo_library_outlined,
                      ),
                label: Text(
                  hasMedia
                      ? 'Choose different media'
                      : 'Choose photos & videos',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.brandDark,
                  minimumSize: const Size(0, 52),
                  padding: const EdgeInsets.symmetric(horizontal: 19),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
