import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/magic_accents.dart';
import '../domain/batch_completion_summary.dart';
import 'compress_controller.dart';

class SuccessPortalScreen extends StatelessWidget {
  const SuccessPortalScreen({
    super.key,
    required this.controller,
    required this.summary,
    required this.onFinished,
  });

  final CompressController controller;
  final BatchCompletionSummary summary;
  final ValueChanged<String?> onFinished;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => PopScope<String?>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !controller.reclaiming) _keepOriginals();
        },
        child: Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF5EFFF), Colors.white, AppColors.canvas],
                stops: [0, .48, 1],
              ),
            ),
            child: SafeArea(
              child: TweenAnimationBuilder<double>(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0, end: 1),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        children: [
                          _PortalArtwork(summary: summary),
                          const SizedBox(height: 24),
                          Text(
                            _title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          const SizedBox(height: 12),
                          _ResultPill(summary: summary),
                          if (summary.issueMessage != null) ...[
                            const SizedBox(height: 14),
                            _IssueCard(message: summary.issueMessage!),
                          ],
                          const SizedBox(height: 26),
                          _StorageAmount(summary: summary),
                          const SizedBox(height: 24),
                          if (summary.canReclaim)
                            _ReclaimActions(
                              reclaiming: controller.reclaiming,
                              reclaimMessage: controller.reclaimMessage,
                              reclaimableBytes: summary.reclaimableBytes,
                              onReclaim: () => _reclaim(context),
                              onKeep: _keepOriginals,
                            )
                          else
                            _DoneAction(
                              allFailed: summary.allFailed,
                              onDone: _keepOriginals,
                            ),
                          const SizedBox(height: 22),
                          const _RecoveryNote(),
                        ],
                      ),
                    ),
                  ),
                ),
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - value)),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _title {
    if (summary.allFailed) return 'Compression failed';
    if (summary.hasIssues) return 'Compression finished';
    return 'Compression complete!';
  }

  void _keepOriginals() {
    if (controller.reclaiming) return;
    controller.dismissCompletion();
    onFinished(null);
  }

  Future<void> _reclaim(BuildContext context) async {
    if (controller.reclaiming) return;
    await controller.reclaimOriginals();
    if (!context.mounted || !controller.originalsReclaimed) return;
    final message = controller.reclaimMessage;
    controller.dismissCompletion();
    onFinished(message);
  }
}

class _PortalArtwork extends StatelessWidget {
  const _PortalArtwork({required this.summary});

  final BatchCompletionSummary summary;

  @override
  Widget build(BuildContext context) {
    final color = summary.allFailed
        ? AppColors.danger
        : summary.hasIssues
        ? AppColors.warning
        : AppColors.brand;
    final icon = summary.allFailed
        ? Icons.close_rounded
        : summary.hasIssues
        ? Icons.priority_high_rounded
        : Icons.auto_fix_high_rounded;

    return Semantics(
      label: summary.allFailed
          ? 'Compression failed'
          : summary.hasIssues
          ? 'Compression completed with issues'
          : 'Compression completed successfully',
      child: SizedBox(
        width: 172,
        height: 172,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 152,
              height: 152,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [color.withValues(alpha: .26), Colors.transparent],
                ),
              ),
            ),
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withValues(alpha: .78), color],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: .32),
                    blurRadius: 34,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 52),
            ),
            const Positioned(
              top: 11,
              right: 14,
              child: MagicSparkle(size: 22, color: AppColors.brandBright),
            ),
            const Positioned(
              left: 2,
              bottom: 35,
              child: MagicSparkle(size: 15),
            ),
            const Positioned(
              right: 5,
              bottom: 21,
              child: MagicSparkle(size: 11, color: AppColors.brandBright),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.summary});

  final BatchCompletionSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = <String>[
      '${summary.savedCount} saved',
      '${summary.verifiedCount} dates verified',
      if (summary.needsReviewCount > 0)
        '${summary.needsReviewCount} need review',
      if (summary.failedCount > 0) '${summary.failedCount} failed',
    ];
    return Semantics(
      label: items.join(', '),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.violetMist,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.violetSoft),
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            const Icon(
              Icons.verified_user_outlined,
              color: AppColors.brand,
              size: 18,
            ),
            Text(
              items.join('  ·  '),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.brandDark,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.warning,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageAmount extends StatelessWidget {
  const _StorageAmount({required this.summary});

  final BatchCompletionSummary summary;

  @override
  Widget build(BuildContext context) {
    if (!summary.canReclaim) {
      return Column(
        children: [
          const Text(
            'Originals remain untouched',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            summary.allFailed
                ? 'Nothing was removed. Review the issue above and try again.'
                : 'No original met every requirement for recoverable storage reclaim.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      );
    }

    return Column(
      children: [
        const Text(
          'Free up about',
          style: TextStyle(
            color: AppColors.inkSoft,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          Formatters.fileSize(summary.reclaimableBytes),
          style: const TextStyle(
            color: AppColors.brand,
            fontSize: 48,
            height: 1.05,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.8,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '${summary.reclaimableCount} verified original${summary.reclaimableCount == 1 ? '' : 's'} eligible',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _ReclaimActions extends StatelessWidget {
  const _ReclaimActions({
    required this.reclaiming,
    required this.reclaimMessage,
    required this.reclaimableBytes,
    required this.onReclaim,
    required this.onKeep,
  });

  final bool reclaiming;
  final String? reclaimMessage;
  final int reclaimableBytes;
  final VoidCallback onReclaim;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (reclaimMessage != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFECDCA)),
            ),
            child: Text(
              reclaimMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _DestructiveReclaimButton(
          reclaiming: reclaiming,
          reclaimableBytes: reclaimableBytes,
          onPressed: onReclaim,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: reclaiming ? null : onKeep,
          child: const Text('Keep originals'),
        ),
      ],
    );
  }
}

class _DestructiveReclaimButton extends StatelessWidget {
  const _DestructiveReclaimButton({
    required this.reclaiming,
    required this.reclaimableBytes,
    required this.onPressed,
  });

  final bool reclaiming;
  final int reclaimableBytes;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final storageAmount = Formatters.fileSize(reclaimableBytes);
    final label = reclaiming
        ? 'Waiting for system confirmation'
        : 'Move originals to Trash';

    return Semantics(
      button: true,
      enabled: !reclaiming,
      label: reclaiming ? label : '$label, free up about $storageAmount',
      child: Material(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: reclaiming ? null : onPressed,
          overlayColor: WidgetStatePropertyAll(
            AppColors.danger.withValues(alpha: 0.16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 62),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showStorageBadge = constraints.maxWidth >= 300;
                  return Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: reclaiming
                            ? const SizedBox.square(
                                dimension: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                                size: 23,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (showStorageBadge && !reclaiming) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2B1719),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.72),
                            ),
                          ),
                          child: Text(
                            storageAmount,
                            style: const TextStyle(
                              color: Color(0xFFFFB4AC),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DoneAction extends StatelessWidget {
  const _DoneAction({required this.allFailed, required this.onDone});

  final bool allFailed;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onDone,
      icon: Icon(allFailed ? Icons.refresh_rounded : Icons.check_rounded),
      label: Text(allFailed ? 'Return and try again' : 'Done'),
    );
  }
}

class _RecoveryNote extends StatelessWidget {
  const _RecoveryNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, size: 17, color: AppColors.brand),
        SizedBox(width: 7),
        Flexible(
          child: Text(
            'Recoverable from system Trash or Recently Deleted',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}
