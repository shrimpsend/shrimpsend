import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../network/connection_diagnostic.dart';
import '../../ui/app_ui.dart';
import '../busy_status_indicator.dart';

Future<void> showConnectionDiagnosticStepHelp(
  BuildContext context,
  ConnectionDiagnosticStepId stepId,
) {
  final l10n = AppLocalizations.of(context);
  final colors = context.appColors;
  final theme = Theme.of(context);
  final help = diagnosticStepHelp(l10n, stepId);

  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        titlePadding: AppDialog.titlePadding,
        contentPadding: AppDialog.confirmContentPadding,
        actionsPadding: AppDialog.actionsPadding,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
        title: Text(help.title, style: theme.textTheme.titleMedium),
        content: SingleChildScrollView(
          child: Text(
            help.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.confirm),
          ),
        ],
      );
    },
  );
}

Future<void> showConnectionDiagnosticSheet(BuildContext context) {
  final colors = context.appColors;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => const ConnectionDiagnosticSheet(),
  );
}

class ConnectionDiagnosticSheet extends ConsumerStatefulWidget {
  const ConnectionDiagnosticSheet({super.key});

  @override
  ConsumerState<ConnectionDiagnosticSheet> createState() =>
      _ConnectionDiagnosticSheetState();
}

class _ConnectionDiagnosticSheetState
    extends ConsumerState<ConnectionDiagnosticSheet> {
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      final running = ref.read(connectionDiagnosticProvider).running;
      if (running) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  void _close() {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectionDiagnosticProvider);
    final colors = context.appColors;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.connectionDiagTitle,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          state.running
                              ? l10n.connectionDiagSubtitleRunning(
                                  state.peerLabel,
                                )
                              : l10n.connectionDiagSubtitleDone(
                                  state.peerLabel,
                                ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _close,
                    tooltip: l10n.cancel,
                    icon: Icon(
                      LucideIcons.x,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: colors.border.withValues(alpha: 0.5),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                children: [
                  ...state.steps.map(
                    (step) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: _DiagnosticStepRow(step: step),
                    ),
                  ),
                  if (state.summary != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted.withValues(alpha: 0.7),
                        borderRadius: AppRadius.small,
                        border: Border.all(
                          color: colors.border.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        state.summary!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticStepRow extends StatelessWidget {
  const _DiagnosticStepRow({required this.step});

  final ConnectionDiagnosticStep step;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final elapsed = _displayElapsed(step);
    final statusLabel = _statusLabel(l10n, step.status);
    final statusColors = _statusColors(colors, theme, step.status);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surfaceMuted.withValues(alpha: 0.7),
        borderRadius: AppRadius.small,
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepStatusIcon(status: step.status, colors: colors),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            step.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: IconButton(
                            onPressed: () => showConnectionDiagnosticStepHelp(
                              context,
                              step.id,
                            ),
                            padding: EdgeInsets.zero,
                            tooltip: l10n.connectionDiagHelpTooltip,
                            icon: Icon(
                              LucideIcons.circleHelp,
                              size: 14,
                              color: colors.textTertiary,
                            ),
                          ),
                        ),
                        if (elapsed != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            l10n.connectionDiagElapsed(elapsed),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    _TagChip(
                      text: statusLabel,
                      foreground: statusColors.foreground,
                      background: statusColors.background,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (step.reason != null && step.reason!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Text(
                step.reason!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _displayElapsed(ConnectionDiagnosticStep step) {
    if (step.status == ConnectionDiagnosticStepStatus.pending) return null;
    if (step.elapsed != null) {
      return formatDiagnosticElapsed(step.elapsed!);
    }
    if (step.status == ConnectionDiagnosticStepStatus.running &&
        step.startedAt != null) {
      return formatDiagnosticElapsed(
        DateTime.now().difference(step.startedAt!),
      );
    }
    return null;
  }

  String _statusLabel(
    AppLocalizations l10n,
    ConnectionDiagnosticStepStatus status,
  ) {
    switch (status) {
      case ConnectionDiagnosticStepStatus.pending:
        return l10n.connectionDiagStatusPending;
      case ConnectionDiagnosticStepStatus.running:
        return l10n.connectionDiagStatusRunning;
      case ConnectionDiagnosticStepStatus.success:
        return l10n.connectionDiagStatusSuccess;
      case ConnectionDiagnosticStepStatus.failure:
        return l10n.connectionDiagStatusFailure;
      case ConnectionDiagnosticStepStatus.skipped:
        return l10n.connectionDiagStatusSkipped;
    }
  }

  ({Color foreground, Color background}) _statusColors(
    AppThemeColors colors,
    ThemeData theme,
    ConnectionDiagnosticStepStatus status,
  ) {
    switch (status) {
      case ConnectionDiagnosticStepStatus.pending:
        return (
          foreground: colors.textSecondary,
          background: colors.surface,
        );
      case ConnectionDiagnosticStepStatus.running:
        return (
          foreground: theme.colorScheme.primary,
          background: theme.colorScheme.primary.withValues(alpha: 0.12),
        );
      case ConnectionDiagnosticStepStatus.success:
        return (
          foreground: colors.success,
          background: colors.successSurface,
        );
      case ConnectionDiagnosticStepStatus.failure:
        return (
          foreground: colors.danger,
          background: colors.dangerSurface,
        );
      case ConnectionDiagnosticStepStatus.skipped:
        return (
          foreground: colors.textTertiary,
          background: colors.surface,
        );
    }
  }
}

class _StepStatusIcon extends StatelessWidget {
  const _StepStatusIcon({required this.status, required this.colors});

  final ConnectionDiagnosticStepStatus status;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (status) {
      case ConnectionDiagnosticStepStatus.pending:
        return Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: colors.textTertiary.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
        );
      case ConnectionDiagnosticStepStatus.running:
        return Padding(
          padding: const EdgeInsets.only(top: 1),
          child: BusyStatusIndicator(
            size: 14,
            strokeWidth: 1.6,
            color: theme.colorScheme.primary,
          ),
        );
      case ConnectionDiagnosticStepStatus.success:
        return Icon(Icons.check_circle, size: 16, color: colors.success);
      case ConnectionDiagnosticStepStatus.failure:
        return Icon(Icons.cancel, size: 16, color: colors.danger);
      case ConnectionDiagnosticStepStatus.skipped:
        return Icon(
          Icons.remove_circle_outline,
          size: 16,
          color: colors.textTertiary,
        );
    }
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.text,
    required this.foreground,
    required this.background,
  });

  final String text;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.pill,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontSize: 10,
        ),
      ),
    );
  }
}

String diagnosticStepTitle(
  AppLocalizations l10n,
  ConnectionDiagnosticStepId id,
) {
  switch (id) {
    case ConnectionDiagnosticStepId.s3:
      return l10n.connectionDiagStepS3;
    case ConnectionDiagnosticStepId.httpDirect:
      return l10n.connectionDiagStepHttpDirect;
    case ConnectionDiagnosticStepId.httpSignaling:
      return l10n.connectionDiagStepHttpSignaling;
    case ConnectionDiagnosticStepId.httpPull:
      return l10n.connectionDiagStepHttpPull;
    case ConnectionDiagnosticStepId.webrtc:
      return l10n.connectionDiagStepWebrtc;
  }
}

class DiagnosticStepHelp {
  const DiagnosticStepHelp({required this.title, required this.body});

  final String title;
  final String body;
}

DiagnosticStepHelp diagnosticStepHelp(
  AppLocalizations l10n,
  ConnectionDiagnosticStepId id,
) {
  switch (id) {
    case ConnectionDiagnosticStepId.httpDirect:
      return DiagnosticStepHelp(
        title: l10n.connectionDiagHelpHttpDirectTitle,
        body: l10n.connectionDiagHelpHttpDirectBody,
      );
    case ConnectionDiagnosticStepId.httpSignaling:
      return DiagnosticStepHelp(
        title: l10n.connectionDiagHelpHttpSignalingTitle,
        body: l10n.connectionDiagHelpHttpSignalingBody,
      );
    case ConnectionDiagnosticStepId.httpPull:
      return DiagnosticStepHelp(
        title: l10n.connectionDiagHelpHttpPullTitle,
        body: l10n.connectionDiagHelpHttpPullBody,
      );
    case ConnectionDiagnosticStepId.webrtc:
      return DiagnosticStepHelp(
        title: l10n.connectionDiagHelpWebrtcTitle,
        body: l10n.connectionDiagHelpWebrtcBody,
      );
    case ConnectionDiagnosticStepId.s3:
      return DiagnosticStepHelp(
        title: l10n.connectionDiagHelpS3Title,
        body: l10n.connectionDiagHelpS3Body,
      );
  }
}
