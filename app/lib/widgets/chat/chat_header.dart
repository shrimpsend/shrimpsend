import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../color_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/device_provider.dart';
import '../../ui/app_ui.dart';
import '../../ui/platform_icon.dart';
import '../devices/device_id_chip.dart';

class ChatHeader extends ConsumerWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final VoidCallback? onBack;
  final VoidCallback? onFileManager;
  final VoidCallback? onOpenS3Settings;
  /// Device/session row (non-S3): opens session menu (e.g. remove peer device).
  final VoidCallback? onSessionDeviceSettings;

  final bool isSelectionMode;
  final int selectedCount;
  final int totalCount;
  final VoidCallback? onExitSelection;
  final VoidCallback? onToggleSelectAll;
  final VoidCallback? onDeleteSelected;

  const ChatHeader({
    super.key,
    this.showBackButton = false,
    this.onBack,
    this.onFileManager,
    this.onOpenS3Settings,
    this.onSessionDeviceSettings,
    this.isSelectionMode = false,
    this.selectedCount = 0,
    this.totalCount = 0,
    this.onExitSelection,
    this.onToggleSelectAll,
    this.onDeleteSelected,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final brightness = theme.brightness;
    final selectedDeviceId = ref.watch(selectedDeviceIdProvider);
    final devices = ref.watch(myDevicesProvider);
    final s3Configured = ref.watch(s3ConfiguredProvider);
    final s3Online = ref.watch(s3OnlineProvider);
    final s3Checking = ref.watch(s3CheckingProvider);
    final reachability = ref.watch(deviceReachabilityProvider);

    final l10n = AppLocalizations.of(context);

    if (isSelectionMode) {
      return AppBar(
        backgroundColor: colors.surface,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: onExitSelection,
        ),
        title: Text(l10n.chatSelectedCount(selectedCount)),
        actions: [
          TextButton(
            onPressed: onToggleSelectAll,
            child: Text(
              selectedCount == totalCount ? l10n.chatDeselectAll : l10n.chatSelectAll,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.trash2, color: colors.danger),
            tooltip: l10n.chatTooltipDelete,
            onPressed: selectedCount == 0 ? null : onDeleteSelected,
          ),
          TextButton(
            onPressed: onExitSelection,
            child: Text(l10n.cancel, style: theme.textTheme.bodyMedium?.copyWith(color: colors.textSecondary)),
          ),
        ],
      );
    }

    final nearbyDevices = ref.watch(nearbyDevicesProvider);
    final myIds = devices.map((d) => d.deviceId).toSet();
    final allDevices = [
      ...devices,
      ...nearbyDevices.where((d) => !myIds.contains(d.deviceId)),
    ];
    final isS3 = selectedDeviceId == s3VirtualDeviceId;
    final device = isS3 ? null : allDevices.where((d) => d.deviceId == selectedDeviceId).firstOrNull;
    final detail = selectedDeviceId != null ? (reachability[selectedDeviceId] ?? DeviceReachDetail.offlineDetail) : DeviceReachDetail.offlineDetail;
    final reachStatus = detail.uiReachStatus;

    Widget titleContent;
    if (isS3) {
      final Color s3DotColor = s3Checking
          ? colors.warning
          : !s3Configured
              ? colors.textTertiary.withValues(alpha: 0.4)
              : s3Online
                  ? colors.success
                  : colors.warning;
      titleContent = Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(LucideIcons.cloud, size: 20, color: Color(0xFF0EA5E9)),
                ),
              ),
              Positioned(
                bottom: -1,
                right: -1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: s3DotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.chatS3RelayTitle, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  s3Checking
                      ? l10n.chatS3StatusChecking
                      : !s3Configured
                          ? l10n.chatS3StatusNotConfigured
                          : s3Online
                              ? l10n.chatS3StatusOnlineSendAll
                              : l10n.chatS3StatusUnavailableCheck,
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (device != null) {
      titleContent = Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Icon(platformIcon(device.platform), size: 20, color: platformColor(device.platform, brightness))),
              ),
              Positioned(
                bottom: -1, right: -1,
                child: Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: switch (reachStatus) {
                      DeviceReachStatus.online => colors.success,
                      DeviceReachStatus.pullOnline => AppColorTheme.s3Color,
                      DeviceReachStatus.checking => colors.warning,
                      DeviceReachStatus.offline =>
                        colors.textTertiary.withValues(alpha: 0.4),
                    },
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (device.displayCode != null) ...[
                      DisplayCodeChip(
                        displayCode: device.displayCode,
                        background: colors.surfaceMuted,
                        foreground: colors.textSecondary,
                        borderColor: colors.border.withValues(alpha: 0.65),
                        tooltipMessage: l10n.chatHeaderDeviceNumberTooltip('${device.displayCode}'),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        switch (reachStatus) {
                          DeviceReachStatus.online => l10n.chatDeviceOnline,
                          DeviceReachStatus.pullOnline =>
                            l10n.chatDevicePullOnline,
                          DeviceReachStatus.checking => l10n.chatDeviceChecking,
                          DeviceReachStatus.offline => l10n.chatDeviceOffline,
                        },
                        style: theme.textTheme.bodySmall?.copyWith(color: colors.textTertiary, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      titleContent = Text(l10n.chatPickDeviceToStart, style: theme.textTheme.bodyMedium?.copyWith(color: colors.textSecondary));
    }

    return AppBar(
      backgroundColor: colors.surface,
      leading: showBackButton
          ? IconButton(icon: const Icon(LucideIcons.arrowLeft), onPressed: onBack, tooltip: l10n.chatTooltipBackDeviceList)
          : null,
      automaticallyImplyLeading: false,
      titleSpacing: showBackButton ? 0 : AppSpacing.sm,
      title: titleContent,
      actions: [
        if (isS3 && onOpenS3Settings != null)
          IconButton(
            icon: Icon(LucideIcons.settings, size: AppSize.appBarActionIcon, color: colors.textSecondary),
            onPressed: onOpenS3Settings,
            tooltip: l10n.chatTooltipS3Settings,
          ),
        if (onFileManager != null)
          IconButton(
            icon: Icon(LucideIcons.folderOpen, size: AppSize.appBarActionIcon, color: colors.textSecondary),
            onPressed: onFileManager,
            tooltip: l10n.chatTooltipFileManager,
          ),
        if (!isS3 && device != null && onSessionDeviceSettings != null)
          IconButton(
            icon: Icon(LucideIcons.settings, size: AppSize.appBarActionIcon, color: colors.textSecondary),
            onPressed: onSessionDeviceSettings,
            tooltip: l10n.chatTooltipSessionSettings,
          ),
      ],
    );
  }
}
