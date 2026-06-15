import 'package:flutter/material.dart';

import '../color_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/device_provider.dart';
import '../ui/app_ui.dart';
import 'connection_bar_view_model.dart';

enum TransferModeDotState {
  verified,
  pullOnly,
  attemptable,
  unchecked,
  unavailable,
}

TransferModeDotState resolveTransferModeDotState({
  required SendMode mode,
  required bool? reachKnownOnline,
  required bool reachPullOnly,
  required bool attemptable,
}) {
  if (mode == SendMode.webrtc && reachKnownOnline == null) {
    return TransferModeDotState.unchecked;
  }
  if (reachKnownOnline == true) {
    return reachPullOnly
        ? TransferModeDotState.pullOnly
        : TransferModeDotState.verified;
  }
  if (attemptable && mode == SendMode.lan) {
    return TransferModeDotState.attemptable;
  }
  return TransferModeDotState.unavailable;
}

TransferModeDotState resolveTransferModeDotStateFromItem(
  ConnectionBarModeItem item,
) {
  return resolveTransferModeDotState(
    mode: item.mode,
    reachKnownOnline: item.reachKnownOnline,
    reachPullOnly: item.reachPullOnly,
    attemptable: item.attemptable,
  );
}

Color transferModeDotColor({
  required TransferModeDotState state,
  required AppThemeColors colors,
  required Color primary,
}) {
  return switch (state) {
    TransferModeDotState.verified => colors.success,
    TransferModeDotState.pullOnly => AppColorTheme.s3Color,
    TransferModeDotState.attemptable => colors.warning,
    TransferModeDotState.unchecked => primary,
    TransferModeDotState.unavailable =>
      colors.textTertiary.withValues(alpha: 0.6),
  };
}

String transferModeDotTooltip(
  AppLocalizations l10n, {
  required ConnectionBarModeItem item,
  required bool s3Configured,
}) {
  final state = resolveTransferModeDotStateFromItem(item);
  switch (item.mode) {
    case SendMode.lan:
      return switch (state) {
        TransferModeDotState.verified => l10n.transportModeDotHttpVerified,
        TransferModeDotState.pullOnly => l10n.transportModeDotHttpPullOnly,
        TransferModeDotState.attemptable => l10n.transportModeDotHttpAttemptable,
        _ => l10n.transportModeDotUnavailable,
      };
    case SendMode.webrtc:
      return switch (state) {
        TransferModeDotState.verified => l10n.transportModeDotWebrtcVerified,
        TransferModeDotState.unchecked => l10n.transportModeDotWebrtcUnchecked,
        _ => l10n.transportModeDotWebrtcUnavailable,
      };
    case SendMode.s3:
      return switch (state) {
        TransferModeDotState.verified => l10n.connectionDiagReasonS3Online,
        _ => s3Configured
            ? l10n.connectionDiagReasonS3Unavailable
            : l10n.connectionDiagReasonS3NotConfigured,
      };
    case SendMode.nearby:
      return l10n.transportModeDotUnavailable;
  }
}

List<({TransferModeDotState state, String label})> transferModeDotLegendEntries(
  AppLocalizations l10n,
) {
  return [
    (state: TransferModeDotState.verified, label: l10n.transportModeDotLegendVerified),
    (state: TransferModeDotState.pullOnly, label: l10n.transportModeDotLegendPullOnly),
    (
      state: TransferModeDotState.attemptable,
      label: l10n.transportModeDotLegendAttemptable,
    ),
    (
      state: TransferModeDotState.unchecked,
      label: l10n.transportModeDotLegendUnchecked,
    ),
    (
      state: TransferModeDotState.unavailable,
      label: l10n.transportModeDotLegendUnavailable,
    ),
  ];
}
