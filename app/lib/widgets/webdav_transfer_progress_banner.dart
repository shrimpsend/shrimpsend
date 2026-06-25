import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/webdav_provider.dart';
import '../services/speed_tracker.dart';
import '../services/webdav_transfer_progress_summary.dart';
import '../services/webdav_transfer_service.dart';
import '../ui/app_ui.dart';

/// Floating upload/download progress above the WebDAV bottom bar (bottom-right).
class WebDavTransferProgressBanner extends ConsumerStatefulWidget {
  const WebDavTransferProgressBanner({
    super.key,
    required this.connectionId,
    this.onTap,
  });

  final int connectionId;
  final VoidCallback? onTap;

  @override
  ConsumerState<WebDavTransferProgressBanner> createState() =>
      _WebDavTransferProgressBannerState();
}

class _WebDavTransferProgressBannerState
    extends ConsumerState<WebDavTransferProgressBanner> {
  Timer? _autoDismissTimer;

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  void _scheduleAutoDismiss(WebDavTransferProgressSummary progress) {
    if (!progress.isUploadBatchComplete) {
      _autoDismissTimer?.cancel();
      _autoDismissTimer = null;
      return;
    }
    if (_autoDismissTimer != null) return;
    _autoDismissTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      WebDavTransferService.instance.clearUploadBatchProgress(
        widget.connectionId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        ref.watch(webDavTransferUiProvider(widget.connectionId)).progress;
    _scheduleAutoDismiss(progress);

    if (!progress.shouldShow) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);

    final title = progress.isUploadBatchComplete
        ? l10n.webdavTransferProgressComplete
        : progress.hasUploadBatch
            ? l10n.webdavTransferProgressTitle(
                progress.uploadSettled,
                progress.uploadBatchTotal,
              )
            : l10n.webdavTransferProgressDownloading(progress.downloadActive);

    final speedParts = <String>[];
    if (progress.uploadSpeedBps > 0) {
      speedParts.add(
        '↑ ${SpeedTracker.formatSpeed(progress.uploadSpeedBps)}',
      );
    }
    if (progress.downloadSpeedBps > 0) {
      speedParts.add(
        '↓ ${SpeedTracker.formatSpeed(progress.downloadSpeedBps)}',
      );
    }

    return Material(
      elevation: 6,
      shadowColor: Colors.black26,
      color: colors.surface,
      borderRadius: AppRadius.medium,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: AppRadius.medium,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.medium,
            border: Border.all(color: colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    progress.isUploadBatchComplete
                        ? LucideIcons.circleCheck
                        : LucideIcons.upload,
                    size: 16,
                    color: progress.isUploadBatchComplete
                        ? colors.success
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (speedParts.isNotEmpty)
                    Text(
                      speedParts.join('  '),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.textSecondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
              if (progress.hasUploadBatch && !progress.isUploadBatchComplete) ...[
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: AppRadius.pill,
                  child: LinearProgressIndicator(
                    value: progress.uploadProgressFraction > 0
                        ? progress.uploadProgressFraction
                        : null,
                    minHeight: 4,
                    backgroundColor: colors.surfaceMuted,
                  ),
                ),
              ],
              if (progress.hasUploadBatch) ...[
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    if (progress.uploadActive > 0)
                      _StatChip(
                        label: l10n.webdavTransferProgressActive(
                          progress.uploadActive,
                        ),
                        color: theme.colorScheme.primary,
                        background: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                      ),
                    if (progress.uploadQueued > 0)
                      _StatChip(
                        label: l10n.webdavTransferProgressQueued(
                          progress.uploadQueued,
                        ),
                        color: colors.textSecondary,
                        background: colors.surfaceMuted,
                      ),
                    if (progress.uploadSucceeded > 0)
                      _StatChip(
                        label: l10n.webdavTransferProgressSucceeded(
                          progress.uploadSucceeded,
                        ),
                        color: colors.success,
                        background: colors.successSurface,
                      ),
                    if (progress.uploadFailed > 0)
                      _StatChip(
                        label: l10n.webdavTransferProgressFailed(
                          progress.uploadFailed,
                        ),
                        color: colors.danger,
                        background: colors.dangerSurface,
                      ),
                  ],
                ),
              ],
              if (!progress.hasUploadBatch && progress.downloadActive > 0) ...[
                const SizedBox(height: AppSpacing.xxs),
                _StatChip(
                  label: l10n.webdavTransferProgressDownloading(
                    progress.downloadActive,
                  ),
                  color: theme.colorScheme.primary,
                  background: theme.colorScheme.primary.withValues(alpha: 0.12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.pill,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
      ),
    );
  }
}
