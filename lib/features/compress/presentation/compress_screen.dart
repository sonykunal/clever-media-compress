import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/magic_accents.dart';
import 'compress_controller.dart';
import 'widgets/comparison_preview.dart';
import 'widgets/compression_controls.dart';
import 'widgets/hero_panel.dart';
import 'widgets/media_strip.dart';

class CompressScreen extends StatelessWidget {
  const CompressScreen({super.key, required this.controller});

  final CompressController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
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
                key: ValueKey(controller.hasMedia),
                slivers: [
                  SliverToBoxAdapter(
                    child: _AppHeader(
                      hasMedia: controller.hasMedia,
                      onClear: controller.clearMedia,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 140),
                    sliver: SliverList.list(
                      children: [
                        if (controller.errorMessage != null) ...[
                          _ErrorBanner(
                            message: controller.errorMessage!,
                            onDismiss: controller.dismissError,
                          ),
                          const SizedBox(height: 12),
                        ],
                        HeroPanel(
                          hasMedia: controller.hasMedia,
                          selecting: controller.selecting,
                          onSelect: controller.selectMedia,
                        ),
                        const SizedBox(height: 22),
                        if (!controller.hasMedia)
                          const _PromiseGrid()
                        else ...[
                          _SelectionHeader(
                            count: controller.media.length,
                            totalBytes: controller.totalInputBytes,
                            onAdd: controller.selectMedia,
                          ),
                          const SizedBox(height: 12),
                          MediaStrip(
                            media: controller.media,
                            results: controller.results,
                            processing: controller.processing,
                            onRemove: controller.removeMedia,
                          ),
                          if (controller.previewMedia != null) ...[
                            const SizedBox(height: 20),
                            ComparisonPreview(
                              media: controller.previewMedia!,
                              preview: controller.preview,
                              loading: controller.previewing,
                            ),
                          ],
                          const SizedBox(height: 16),
                          CompressionControls(
                            settings: controller.settings,
                            enabled: !controller.processing,
                            onQualityChanged: controller.setQuality,
                            onResolutionChanged: controller.setResolutionScale,
                            onMetadataChanged: controller.setPreserveMetadata,
                            onLocationChanged: controller.setPreserveLocation,
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
          bottomNavigationBar: controller.hasMedia
              ? _BatchActionBar(controller: controller)
              : null,
        );
      },
    );
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
                onPressed: controller.processing ? null : controller.startBatch,
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
