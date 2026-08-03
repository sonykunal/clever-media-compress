import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/magic_accents.dart';
import '../../domain/compression_settings.dart';
import '../../domain/media_asset.dart';

class VideoPreviewCard extends StatelessWidget {
  const VideoPreviewCard({
    super.key,
    required this.media,
    required this.recipe,
  });

  final SelectedMedia media;
  final MediaCompressionRecipe recipe;

  @override
  Widget build(BuildContext context) {
    final estimatedBytes = recipe.estimateOutputBytes(media.byteSize);
    final savedPercent = media.byteSize == 0
        ? 0
        : ((1 - estimatedBytes / media.byteSize) * 100).clamp(0, 99).round();
    final scalePercent = (recipe.resolutionScale * 100).round();

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
                        'Video preview',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Previewing ${media.name}',
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
                _SavedPill(savedPercent: savedPercent),
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _VideoFrame(media: media),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x22000000), Color(0x66000000)],
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 12,
                        top: 75,
                        child: _PreviewFrameBadge(),
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: _PreviewLabel(
                          title: 'ORIGINAL',
                          value: Formatters.fileSize(media.byteSize),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: _PreviewLabel(
                          title: 'ESTIMATED',
                          value: Formatters.fileSize(estimatedBytes),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _VideoMetric(
                              icon: Icons.tune_rounded,
                              label: 'Quality',
                              value: '${recipe.quality}%',
                            ),
                            _VideoMetric(
                              icon: Icons.aspect_ratio_rounded,
                              label: 'Frame',
                              value: '$scalePercent%',
                            ),
                            const _VideoMetric(
                              icon: Icons.movie_creation_outlined,
                              label: 'Container',
                              value: 'MP4*',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Preview frame only. Final video compression happens on submit. MP4 is used when supported.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoFrame extends StatelessWidget {
  const _VideoFrame({required this.media});

  final SelectedMedia media;

  @override
  Widget build(BuildContext context) {
    final thumbnailPath = media.thumbnailPath;
    if (thumbnailPath != null) {
      return Image.file(
        File(thumbnailPath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _VideoFallback(),
      );
    }
    return const _VideoFallback();
  }
}

class _VideoFallback extends StatelessWidget {
  const _VideoFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.violetMist, AppColors.violetSoft],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.movie_creation_outlined,
          color: AppColors.brand,
          size: 54,
        ),
      ),
    );
  }
}

class _PreviewFrameBadge extends StatelessWidget {
  const _PreviewFrameBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .84),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .88)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.video_collection_outlined,
            color: AppColors.brand,
            size: 15,
          ),
          SizedBox(width: 6),
          Text(
            'Preview frame',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedPill extends StatelessWidget {
  const _SavedPill({required this.savedPercent});

  final int savedPercent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.violetMist,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.violetSoft),
      ),
      child: Text(
        '~$savedPercent% smaller',
        style: const TextStyle(
          color: AppColors.brandDark,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PreviewLabel extends StatelessWidget {
  const _PreviewLabel({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .84),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: .88)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.brandDark,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoMetric extends StatelessWidget {
  const _VideoMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .78)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.brand),
          const SizedBox(width: 5),
          Text(
            '$label ',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
