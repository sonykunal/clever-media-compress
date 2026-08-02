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
    required this.processing,
  });

  final List<SelectedMedia> media;
  final Map<String, CompressionResult> results;
  final ValueChanged<String> onRemove;
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
            onRemove: processing ? null : () => onRemove(item.id),
          );
        },
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.media, this.result, this.onRemove});

  final SelectedMedia media;
  final CompressionResult? result;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
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
                        : const _TypeIcon(
                            icon: Icons.play_circle_outline_rounded,
                          ),
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
