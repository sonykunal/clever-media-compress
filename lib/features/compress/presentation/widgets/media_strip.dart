import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/compression_result.dart';
import '../../domain/media_asset.dart';

class MediaStrip extends StatelessWidget {
  const MediaStrip({
    super.key,
    required this.media,
    required this.results,
    required this.onRemove,
    required this.onPreviewSelect,
    this.previewMediaId,
    required this.processing,
  });

  final List<SelectedMedia> media;
  final Map<String, CompressionResult> results;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onPreviewSelect;
  final String? previewMediaId;
  final bool processing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: media.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = media[index];
          return _MediaTile(
            media: item,
            result: results[item.id],
            selectedForPreview: item.id == previewMediaId,
            onPreviewSelect: () => onPreviewSelect(item.id),
            onRemove: processing ? null : () => onRemove(item.id),
          );
        },
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.media,
    required this.selectedForPreview,
    this.result,
    this.onPreviewSelect,
    this.onRemove,
  });

  final SelectedMedia media;
  final bool selectedForPreview;
  final CompressionResult? result;
  final VoidCallback? onPreviewSelect;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              button: onPreviewSelect != null,
              selected: selectedForPreview,
              label: media.isImage
                  ? '${media.name}, preview image'
                  : '${media.name}, preview video frame',
              child: GestureDetector(
                onTap: onPreviewSelect,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.all(selectedForPreview ? 3 : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(
                      color: selectedForPreview
                          ? AppColors.brand
                          : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: selectedForPreview
                        ? [
                            BoxShadow(
                              color: AppColors.brand.withValues(alpha: .18),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: AppColors.violetMist,
                          child: media.isImage
                              ? Image.file(
                                  File(media.path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const _TypeIcon(
                                    icon: Icons.image_not_supported_outlined,
                                  ),
                                )
                              : _VideoTileContent(media: media),
                        ),
                        if (result?.status == CompressionJobStatus.processing)
                          const ColoredBox(
                            color: Color(0x66000000),
                            child: Center(
                              child: SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        if (result?.status == CompressionJobStatus.completed)
                          Positioned(
                            left: 7,
                            bottom: 7,
                            child: _StatusDot(
                              color: result!.captureDateVerified
                                  ? AppColors.brand
                                  : AppColors.warning,
                              icon: result!.captureDateVerified
                                  ? Icons.check_rounded
                                  : Icons.question_mark_rounded,
                            ),
                          ),
                        if (result?.status == CompressionJobStatus.failed)
                          const Positioned(
                            left: 7,
                            bottom: 7,
                            child: _StatusDot(
                              color: AppColors.danger,
                              icon: Icons.priority_high_rounded,
                            ),
                          ),
                        if (onRemove != null)
                          Positioned(
                            right: 5,
                            top: 5,
                            child: GestureDetector(
                              onTap: onRemove,
                              child: Container(
                                width: 25,
                                height: 25,
                                decoration: const BoxDecoration(
                                  color: Color(0xB3000000),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _caption,
            maxLines: 1,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String get _caption {
    if (result?.status == CompressionJobStatus.failed) return 'Failed';
    if (result?.status == CompressionJobStatus.completed) {
      return result!.captureDateVerified ? 'Date verified' : 'Needs review';
    }
    if (selectedForPreview) return 'Previewing';
    return Formatters.fileSize(media.byteSize);
  }
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(child: Icon(icon, color: AppColors.brand, size: 33));
  }
}

class _VideoTileContent extends StatelessWidget {
  const _VideoTileContent({required this.media});

  final SelectedMedia media;

  @override
  Widget build(BuildContext context) {
    final thumbnailPath = media.thumbnailPath;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumbnailPath != null)
          Image.file(
            File(thumbnailPath),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _VideoFallback(),
          )
        else
          const _VideoFallback(),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x22000000), Color(0x55000000)],
            ),
          ),
        ),
        const Positioned(left: 7, bottom: 7, child: _VideoBadge()),
      ],
    );
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
          size: 32,
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, color: Colors.white, size: 14),
    );
  }
}

class _VideoBadge extends StatelessWidget {
  const _VideoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .9)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_rounded, size: 11, color: AppColors.brand),
          SizedBox(width: 3),
          Text(
            'VIDEO',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
        ],
      ),
    );
  }
}
