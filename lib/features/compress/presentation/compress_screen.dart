import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/magic_accents.dart';
import 'compress_controller.dart';
import 'success_portal_screen.dart';
import 'widgets/comparison_preview.dart';
import 'widgets/compression_controls.dart';
import 'widgets/hero_panel.dart';
import 'widgets/media_strip.dart';
import 'widgets/video_preview_card.dart';

class CompressScreen extends StatefulWidget {
  const CompressScreen({super.key, required this.controller});

  final CompressController controller;

  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  bool _previewScrollLocked = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final summary = widget.controller.completionSummary;
        if (summary != null) {
          return SuccessPortalScreen(
            controller: widget.controller,
            summary: summary,
            onFinished: _finishPortal,
          );
        }
        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFCFBFD), AppColors.canvas],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: CustomScrollView(
                key: ValueKey(widget.controller.hasMedia),
                physics: _previewScrollLocked
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _AppHeader(
                      hasMedia: widget.controller.hasMedia,
                      onClear: widget.controller.clearMedia,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 140),
                    sliver: SliverList.list(
                      children: [
                        if (widget.controller.errorMessage != null) ...[
                          _ErrorBanner(
                            message: widget.controller.errorMessage!,
                            onDismiss: widget.controller.dismissError,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (widget.controller.permissionMessage != null) ...[
                          _PermissionBanner(
                            message: widget.controller.permissionMessage!,
                            canOpenSettings:
                                widget.controller.canOpenPermissionSettings,
                            onAllow: () =>
                                widget.controller.requestFullMediaAccess(),
                            onOpenSettings: () =>
                                widget.controller.openPermissionSettings(),
                            onDismiss:
                                widget.controller.dismissPermissionMessage,
                          ),
                          const SizedBox(height: 12),
                        ],
                        HeroPanel(
                          hasMedia: widget.controller.hasMedia,
                          selecting: widget.controller.selecting,
                          onSelect: widget.controller.selectMedia,
                        ),
                        const SizedBox(height: 22),
                        if (!widget.controller.hasMedia)
                          const _PromiseGrid()
                        else ...[
                          _SelectionHeader(
                            count: widget.controller.media.length,
                            totalBytes: widget.controller.totalInputBytes,
                            onAdd: widget.controller.selectMedia,
                          ),
                          const SizedBox(height: 12),
                          MediaStrip(
                            media: widget.controller.media,
                            results: widget.controller.results,
                            processing: widget.controller.processing,
                            previewMediaId: widget.controller.previewMedia?.id,
                            onPreviewSelect:
                                widget.controller.selectPreviewMedia,
                            onRemove: widget.controller.removeMedia,
                          ),
                          if (widget.controller.previewMedia != null) ...[
                            const SizedBox(height: 20),
                            if (widget.controller.previewMedia!.isImage)
                              ComparisonPreview(
                                media: widget.controller.previewMedia!,
                                preview: widget.controller.preview,
                                loading: widget.controller.previewing,
                                onScrollLockChanged: _setPreviewScrollLocked,
                              )
                            else
                              VideoPreviewCard(
                                media: widget.controller.previewMedia!,
                                recipe: widget.controller.settings.video,
                              ),
                          ],
                          const SizedBox(height: 16),
                          CompressionControls(
                            imageRecipe: widget.controller.settings.image,
                            videoRecipe: widget.controller.settings.video,
                            imageCount: widget.controller.imageCount,
                            videoCount: widget.controller.videoCount,
                            preserveMetadata:
                                widget.controller.settings.preserveMetadata,
                            preserveLocation:
                                widget.controller.settings.preserveLocation,
                            enabled:
                                !widget.controller.processing &&
                                !widget.controller.reclaiming,
                            onImageQualityChanged:
                                widget.controller.setImageQuality,
                            onImageResolutionChanged:
                                widget.controller.setImageResolutionScale,
                            onVideoQualityChanged:
                                widget.controller.setVideoQuality,
                            onVideoResolutionChanged:
                                widget.controller.setVideoResolutionScale,
                            onMetadataChanged:
                                widget.controller.setPreserveMetadata,
                            onLocationChanged:
                                widget.controller.setPreserveLocation,
                          ),
                          const SizedBox(height: 16),
                          const _OutputPromise(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: widget.controller.hasMedia
              ? _BatchActionBar(controller: widget.controller)
              : null,
        );
      },
    );
  }

  void _setPreviewScrollLocked(bool locked) {
    if (_previewScrollLocked == locked || !mounted) return;
    setState(() => _previewScrollLocked = locked);
  }

  void _finishPortal(String? reclaimMessage) {
    if (reclaimMessage != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(reclaimMessage)));
      });
    }
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({required this.hasMedia, required this.onClear});

  final bool hasMedia;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      child: Row(
        children: [
          const MagicIconBadge(),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clever Compress',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.3,
                  ),
                ),
                Text(
                  'Metadata-protected media',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (hasMedia)
            TextButton(
              onPressed: onClear,
              child: const Text(
                'Clear',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else
            IconButton.filledTonal(
              onPressed: () => _showAbout(context),
              icon: const Icon(Icons.info_outline_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.border),
              ),
            ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Why Clever Compress?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 12),
            Text(
              'Most compressors create a new file without its original capture date. Clever Compress restores and verifies that date before publishing the result.',
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionHeader extends StatelessWidget {
  const _SelectionHeader({
    required this.count,
    required this.totalBytes,
    required this.onAdd,
  });

  final int count;
  final int totalBytes;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Formatters.plural(count, 'item'),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${Formatters.fileSize(totalBytes)} selected',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Replace'),
        ),
      ],
    );
  }
}

class _PromiseGrid extends StatelessWidget {
  const _PromiseGrid();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _PromiseCard(
            icon: Icons.calendar_month_outlined,
            title: 'Date stays',
            caption: 'Gallery order protected',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _PromiseCard(
            icon: Icons.photo_size_select_small_outlined,
            title: 'Size drops',
            caption: 'Quality stays visible',
          ),
        ),
      ],
    );
  }
}

class _PromiseCard extends StatelessWidget {
  const _PromiseCard({
    required this.icon,
    required this.title,
    required this.caption,
  });

  final IconData icon;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.violetMist,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.violetSoft),
            ),
            child: Icon(icon, color: AppColors.brand, size: 22),
          ),
          const SizedBox(height: 13),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(
            caption,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _OutputPromise extends StatelessWidget {
  const _OutputPromise();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.violetMist,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.violetSoft),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MagicIconBadge(size: 42, iconSize: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verification, not assumptions',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'The final file is reopened and its capture date compared. Outputs without a matching source date are clearly marked “Needs review.”',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECDCA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFB42318), fontSize: 12),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({
    required this.message,
    required this.canOpenSettings,
    required this.onAllow,
    required this.onOpenSettings,
    required this.onDismiss,
  });

  final String message;
  final bool canOpenSettings;
  final VoidCallback onAllow;
  final VoidCallback onOpenSettings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F0FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4D1FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.photo_library_outlined,
            color: AppColors.brand,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: onAllow,
                      icon: const Icon(Icons.verified_user_outlined, size: 16),
                      label: const Text('Allow full access'),
                    ),
                    if (canOpenSettings)
                      TextButton.icon(
                        onPressed: onOpenSettings,
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        label: const Text('Open settings'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _BatchActionBar extends StatelessWidget {
  const _BatchActionBar({required this.controller});

  final CompressController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: .08),
            blurRadius: 25,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.processing) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Protecting your timeline…',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${(controller.progress * 100).round()}%',
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: controller.progress,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(99),
                  color: AppColors.brand,
                  backgroundColor: AppColors.violetSoft,
                ),
                const SizedBox(height: 10),
              ],
              FilledButton.icon(
                onPressed: controller.canStartBatch
                    ? controller.startBatch
                    : null,
                icon: Icon(
                  controller.processing
                      ? Icons.hourglass_top_rounded
                      : Icons.auto_awesome_rounded,
                ),
                label: Text(
                  controller.processing
                      ? 'Compression in progress'
                      : 'Compress ${Formatters.plural(controller.media.length, 'item')}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
