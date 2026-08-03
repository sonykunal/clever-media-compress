import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/magic_accents.dart';

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
    if (hasMedia) {
      return const _SelectedHero();
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: .06),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: 0,
            top: 2,
            child: MagicSparkle(size: 18, color: AppColors.violetSoft),
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
                  color: AppColors.violetMist,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.violetSoft),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: AppColors.brand,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'CHRONOLOGY SAFE',
                      style: TextStyle(
                        color: AppColors.brandDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const MagicTransformArtwork(),
              const SizedBox(height: 20),
              const Text(
                'Smaller media.\nSame moment.',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 34,
                  height: 1.03,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                'Compress a whole batch while keeping the capture date that your gallery uses for sorting.',
                style: const TextStyle(
                  color: AppColors.muted,
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
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        hasMedia
                            ? Icons.add_photo_alternate_outlined
                            : Icons.auto_fix_high_rounded,
                      ),
                label: Text('Choose photos & videos'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
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

class _SelectedHero extends StatelessWidget {
  const _SelectedHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: .045),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MagicIconBadge(size: 46, iconSize: 22, inverted: true),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smaller media.\nSame moment.',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 21,
                    height: 1.03,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Compress a whole batch while keeping the capture date that your gallery uses for sorting.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
