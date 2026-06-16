import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../network/connection_bar_view_model.dart';
import '../../network/connection_orchestrator.dart';
import '../../network/transfer_mode_dot.dart';
import '../../providers/app_locale.dart';
import '../../providers/auth_provider.dart';
import '../../providers/device_provider.dart';
import '../../ui/app_ui.dart';
import '../busy_status_indicator.dart';
import 'transfer_mode_dot_legend.dart';

class TransferModeBar extends ConsumerWidget {
  final VoidCallback? onRefresh;
  final Future<void> Function(SendMode mode)? onModeSelected;
  final bool embedded;

  const TransferModeBar({
    super.key,
    this.onRefresh,
    this.onModeSelected,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final selectedDeviceId = ref.watch(selectedDeviceIdProvider);
    final sendMode = ref.watch(selectedSendModeProvider);
    final s3Configured = ref.watch(s3ConfiguredProvider);
    final sessionProbing = ref.watch(
      deviceReachabilityProvider.select((map) {
        final id = selectedDeviceId;
        if (id == null) return false;
        return map[id]?.checking ?? false;
      }),
    );
    final orchestrator = ref.watch(connectionOrchestratorProvider);
    final isLoggedIn = ref.watch(authProvider).isLoggedIn;
    final isRegisteredPeer =
        selectedDeviceId != null &&
        ref.watch(myDevicesProvider).any((d) => d.deviceId == selectedDeviceId);
    final l10n = lookupAppLocalizations(ref.watch(appLocaleProvider));

    if (selectedDeviceId == null || selectedDeviceId == s3VirtualDeviceId) {
      return const SizedBox.shrink();
    }

    final reach = ref.watch(
      deviceReachabilityProvider.select(
        (map) => map[selectedDeviceId] ?? DeviceReachDetail.offlineDetail,
      ),
    );

    final allModes =
        buildConnectionBarModeItems(
              candidates: orchestrator.candidates,
              currentMode: sendMode,
              l10n: l10n,
              localOs: Platform.operatingSystem,
              isLoggedIn: isLoggedIn,
              isRegisteredPeer: isRegisteredPeer,
              transferBarLabels: true,
              reach: reach,
            )
            .where((item) {
              return item.mode != SendMode.nearby || item.isSelected;
            })
            .toList();

    if (allModes.isEmpty) return const SizedBox.shrink();

    final sorted = [...allModes]
      ..sort((a, b) {
        if (a.available == b.available) return 0;
        return a.available ? -1 : 1;
      });

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: embedded ? 0 : AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: embedded
            ? null
            : Border(
                bottom: BorderSide(
                  color: colors.border.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
        color: embedded ? Colors.transparent : colors.surface,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            l10n.transportModeLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const TransferModeDotLegendButton(),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Wrap(
              spacing: 2,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: sorted.map((m) {
                return _TransferModeChip(
                  item: m,
                  s3Configured: s3Configured,
                  onModeSelected: onModeSelected,
                );
              }).toList(),
            ),
          ),
          if (onRefresh != null)
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                icon: sessionProbing
                    ? BusyStatusIndicator(
                        size: 14,
                        strokeWidth: 1.5,
                        color: colors.textTertiary,
                      )
                    : Icon(
                        LucideIcons.refreshCw,
                        size: 14,
                        color: colors.textTertiary,
                      ),
                onPressed: sessionProbing ? null : onRefresh,
                tooltip: l10n.connectionBarRefreshOnlineStatus,
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }
}

class _TransferModeChip extends StatelessWidget {
  const _TransferModeChip({
    required this.item,
    required this.s3Configured,
    required this.onModeSelected,
  });

  final ConnectionBarModeItem item;
  final bool s3Configured;
  final Future<void> Function(SendMode mode)? onModeSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final isSelected = item.isSelected;
    final primary = theme.colorScheme.primary;
    final canTap =
        onModeSelected != null &&
        item.attemptable &&
        (!isSelected ||
            (item.mode == SendMode.webrtc && item.reachKnownOnline == null));
    final dotState = resolveTransferModeDotStateFromItem(item);
    final dotColor = transferModeDotColor(
      state: dotState,
      colors: colors,
      primary: primary,
    );
    final tooltip = transferModeDotTooltip(
      l10n,
      item: item,
      s3Configured: s3Configured,
    );

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canTap ? () => unawaited(onModeSelected!(item.mode)) : null,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? primary.withValues(alpha: 0.08)
                  : item.attemptable
                  ? colors.surfaceMuted.withValues(alpha: 0.6)
                  : colors.surfaceMuted.withValues(alpha: 0.3),
              border: isSelected
                  ? Border.all(color: primary, width: 1.5)
                  : Border.all(color: Colors.transparent, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? primary
                        : item.attemptable
                        ? colors.textPrimary
                        : colors.textTertiary.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
