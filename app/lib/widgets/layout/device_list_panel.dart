import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../api/api.dart';
import '../../l10n/app_brand.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../preferences/locale_region_store.dart';
import '../../providers/device_provider.dart';
import '../../providers/app_mode_provider.dart';
import '../../providers/webdav_provider.dart';
import '../../services/auth_session_controller.dart';
import '../../ui/app_ui.dart';
import '../../ui/platform_performance.dart';
import '../../utils/runtime_platform.dart';
import '../busy_status_indicator.dart';
import '../devices/device_conversation_item.dart';
import '../devices/device_id_chip.dart';
import '../../screens/webdav_shell_screen.dart';
import '../../screens/webdav_connection_screen.dart';
import '../../services/webdav_credential_store.dart';
import '../../utils/toast.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../webdav/webdav_connection_item.dart';

/// Matches [MainLayout] / [ChatScreen] narrow breakpoint (floating tab bar inset).
const double _kNarrowLayoutBreakpoint = 768;

/// Sort by device state only: online before offline. [checking] is probe UI, not state.
int _reachSortPriority(DeviceReachDetail detail) {
  return detail.isOnline ? 0 : 1;
}

class DeviceListPanel extends ConsumerWidget {
  final bool connected;
  final String deviceName;

  /// Prefer this for matching [DeviceDto.deviceId] in lists when non-empty
  /// (e.g. [ChatScreen] sets it right after [getOrCreateDeviceId]).
  final String? myDeviceId;
  final bool statusCheckDone;
  final bool isLoggedIn;
  final AuthSessionPhase authSessionPhase;
  final VoidCallback onShowSettings;
  final VoidCallback? onSearch;
  final VoidCallback? onAddConnectionTap;
  final VoidCallback? onFileManager;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onLoginTap;

  /// When false (mobile tab shell): hide bottom online-count row — tabs replace it.
  final bool showBottomStatusBar;

  /// When false (mobile tab shell): hide header file + settings — bottom bar has them.
  final bool showHeaderFileAndSettings;

  /// Narrow / mobile home: refresh in the title bar instead of only the footer row.
  final bool showHeaderRefresh;

  const DeviceListPanel({
    super.key,
    required this.connected,
    required this.deviceName,
    this.myDeviceId,
    this.statusCheckDone = true,
    this.isLoggedIn = true,
    this.authSessionPhase = AuthSessionPhase.authenticated,
    required this.onShowSettings,
    this.onSearch,
    this.onAddConnectionTap,
    this.onFileManager,
    this.onRefresh,
    this.onLoginTap,
    this.showBottomStatusBar = true,
    this.showHeaderFileAndSettings = true,
    this.showHeaderRefresh = false,
  });

  (String label, Color color) _resolveStatus(
    AppLocalizations l10n,
    AppThemeColors colors,
  ) {
    switch (authSessionPhase) {
      case AuthSessionPhase.validating:
        return (l10n.devicePanelStatusValidating, colors.warning);
      case AuthSessionPhase.unauthenticated:
        return (l10n.settingsBadgeNotSignedIn, colors.textTertiary);
      case AuthSessionPhase.sessionExpired:
        return (l10n.devicePanelStatusSessionExpired, colors.danger);
      case AuthSessionPhase.networkUnavailable:
        return (l10n.devicePanelStatusServerUnreachable, colors.danger);
      case AuthSessionPhase.authenticated:
        if (connected) {
          return (l10n.devicePanelStatusConnected, colors.success);
        }
        return (l10n.devicePanelStatusConnecting, colors.warning);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final isOffline = ref.watch(effectiveOfflineModeProvider);

    final currentDeviceId = () {
      final passed = myDeviceId;
      if (passed != null && passed.isNotEmpty) return passed;
      return ref.watch(deviceInfoProvider).valueOrNull?.id;
    }();
    final myDevices = ref.watch(myDevicesProvider);
    int? selfDisplayCode;
    if (currentDeviceId != null) {
      for (final d in myDevices) {
        if (d.deviceId == currentDeviceId) {
          selfDisplayCode = d.displayCode;
          break;
        }
      }
    }
    final nearbyDevices = ref.watch(nearbyDevicesProvider);
    final myIds = myDevices.map((d) => d.deviceId).toSet();
    final allDevices = [
      ...myDevices,
      ...nearbyDevices.where((d) => !myIds.contains(d.deviceId)),
    ];
    final otherDevices = allDevices
        .where((d) => d.deviceId != currentDeviceId)
        .toList();
    final selectedDeviceId = ref.watch(selectedDeviceIdProvider);
    final s3Configured = ref.watch(s3ConfiguredProvider);
    final s3Online = ref.watch(s3OnlineProvider);
    final s3Checking = ref.watch(s3CheckingProvider);
    final reachability = ref.watch(deviceReachabilityProvider);
    final probing = ref.watch(devicesProbingProvider);
    final webDavAsync = ref.watch(webDavConnectionsProvider);
    final webDavConnections = isLoggedIn && !isOffline
        ? webDavAsync.valueOrNull ?? []
        : <WebDavConnectionSummary>[];

    final sorted = [...otherDevices]
      ..sort((a, b) {
        final aMine = myIds.contains(a.deviceId);
        final bMine = myIds.contains(b.deviceId);
        if (aMine != bMine) return aMine ? -1 : 1;
        final aReach = reachability[a.deviceId] ?? DeviceReachDetail.offlineDetail;
        final bReach = reachability[b.deviceId] ?? DeviceReachDetail.offlineDetail;
        final byReach =
            _reachSortPriority(aReach) - _reachSortPriority(bReach);
        if (byReach != 0) return byReach;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final onlineCount = otherDevices
        .where(
          (d) => (reachability[d.deviceId] ?? DeviceReachDetail.offlineDetail)
              .isOnline,
        )
        .length;

    final (statusLabel, statusColor) = _resolveStatus(l10n, colors);

    return ColoredBox(
      color: colors.background,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colors.border, width: 0.5),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.small,
                    child: Image.asset(
                      'assets/logo.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: (authSessionPhase ==
                                      AuthSessionPhase.sessionExpired ||
                                  (!isLoggedIn && statusCheckDone))
                              ? onLoginTap
                              : null,
                          child: Row(
                            children: [
                              Flexible(
                                child:
                                    ValueListenableBuilder<LocaleRegionState>(
                                      valueListenable:
                                          LocaleRegionStoreScope.of(
                                            context,
                                          ).notifier,
                                      builder: (context, lr, _) {
                                        return Text(
                                          brandDisplayName(
                                            context,
                                            lr.serviceRegion,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        );
                                      },
                                    ),
                              ),
                              const SizedBox(width: 5),
                              if (!statusCheckDone)
                                BusyStatusIndicator(
                                  size: 7,
                                  strokeWidth: 1.2,
                                  color: statusColor,
                                )
                              else
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  statusLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: statusColor,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              if (!isLoggedIn && statusCheckDone) ...[
                                const SizedBox(width: 2),
                                Icon(
                                  LucideIcons.chevronRight,
                                  size: 10,
                                  color: statusColor,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (deviceName.isNotEmpty || selfDisplayCode != null)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (selfDisplayCode != null) ...[
                                DisplayCodeChip(
                                  displayCode: selfDisplayCode,
                                  background: colors.surfaceMuted,
                                  foreground: colors.textSecondary,
                                  borderColor: colors.border.withValues(
                                    alpha: 0.65,
                                  ),
                                  tooltipMessage: l10n
                                      .chatHeaderDeviceNumberTooltip(
                                        '$selfDisplayCode',
                                      ),
                                ),
                                if (deviceName.isNotEmpty)
                                  const SizedBox(width: 4),
                              ],
                              if (deviceName.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    deviceName,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.textTertiary,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (onSearch != null && !isOffline)
                    IconButton(
                      icon: const Icon(
                        LucideIcons.search,
                        size: AppSize.appBarActionIcon,
                      ),
                      onPressed: onSearch,
                      tooltip: l10n.fmSearchTooltip,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (onAddConnectionTap != null && !isOffline)
                    IconButton(
                      icon: const Icon(
                        LucideIcons.plus,
                        size: AppSize.appBarActionIcon,
                      ),
                      onPressed: onAddConnectionTap,
                      tooltip: l10n.webdavAddMenuTooltip,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (showHeaderRefresh && onRefresh != null)
                    _DevicePanelRefreshButton(
                      probing: probing,
                      onRefresh: onRefresh,
                      tooltip: l10n.connectionBarRefreshOnlineStatus,
                      iconSize: AppSize.appBarActionIcon,
                    ),
                  if (showHeaderFileAndSettings && onFileManager != null)
                    IconButton(
                      icon: const Icon(
                        LucideIcons.folderOpen,
                        size: AppSize.appBarActionIcon,
                      ),
                      onPressed: onFileManager,
                      tooltip: l10n.chatTooltipFileManager,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (showHeaderFileAndSettings)
                    IconButton(
                      icon: const Icon(
                        LucideIcons.settings,
                        size: AppSize.appBarActionIcon,
                      ),
                      onPressed: onShowSettings,
                      tooltip: l10n.settingsTitle,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ),
          // Device list
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scrollBottom =
                    constraints.maxWidth < _kNarrowLayoutBreakpoint
                    ? AppLayout.floatingBottomBarScrollInset(context)
                    : 0.0;
                final listChildren = <Widget>[
                  if ((s3Configured || s3Checking) && !isOffline)
                    _S3VirtualDeviceItem(
                      selected: selectedDeviceId == s3VirtualDeviceId,
                      configured: s3Configured,
                      online: s3Online,
                      checking: s3Checking,
                      onTap: () => ref
                          .read(selectedDeviceIdProvider.notifier)
                          .select(s3VirtualDeviceId),
                    ),
                  if (webDavConnections.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.xs,
                      ),
                      child: Text(
                        l10n.webdavSectionTitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ...webDavConnections.map(
                      (conn) => WebDavConnectionItem(
                        key: ValueKey('webdav_${conn.id}'),
                        connection: conn,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  WebDavShellScreen(connection: conn),
                            ),
                          );
                        },
                        onMore: () => _showWebDavConnectionMenu(
                          context,
                          ref,
                          conn,
                        ),
                      ),
                    ),
                  ],
                  ...sorted.map(
                    (device) => _DeviceListReachRow(
                      key: ValueKey(device.deviceId),
                      device: device,
                      isMyDevice: myIds.contains(device.deviceId),
                      selected: selectedDeviceId == device.deviceId,
                      onTap: () => ref
                          .read(selectedDeviceIdProvider.notifier)
                          .select(device.deviceId),
                    ),
                  ),
                ];
                final isEmpty = sorted.isEmpty &&
                    !(s3Configured || s3Checking) &&
                    webDavConnections.isEmpty;
                final emptyBody = Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg + scrollBottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.devicePanelEmptyNoOtherDevices,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        isOffline
                            ? l10n.devicePanelEmptyHintOfflineLan
                            : l10n.devicePanelEmptyHintOnlineAccount,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textTertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );

                Widget body;
                if (isEmpty) {
                  body = Center(child: emptyBody);
                } else {
                  body = ListView(
                    padding: EdgeInsets.fromLTRB(0, 2, 0, 2 + scrollBottom),
                    children: listChildren,
                  );
                }

                if (RuntimePlatform.isMobile && onRefresh != null) {
                  body = RefreshIndicator(
                    onRefresh: onRefresh!,
                    color: theme.colorScheme.primary,
                    child: isEmpty
                        ? CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: emptyBody,
                              ),
                            ],
                          )
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              0,
                              2,
                              0,
                              2 + scrollBottom,
                            ),
                            children: listChildren,
                          ),
                  );
                }

                return body;
              },
            ),
          ),
          if (showBottomStatusBar && !showHeaderRefresh)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        probing
                            ? l10n.chatS3StatusChecking
                            : l10n.devicePanelDevicesOnlineCount(onlineCount),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (onRefresh != null)
                      _DevicePanelRefreshButton(
                        probing: probing,
                        onRefresh: onRefresh,
                        tooltip: l10n.connectionBarRefreshOnlineStatus,
                        iconSize: 16,
                        iconColor: colors.textTertiary,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _S3VirtualDeviceItem extends StatelessWidget {
  final bool selected;
  final bool configured;
  final bool online;
  final bool checking;
  final VoidCallback onTap;

  const _S3VirtualDeviceItem({
    required this.selected,
    required this.configured,
    required this.online,
    required this.checking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final lightweightTap = AppPlatformPerformance.preferLightweightTapFeedback;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 4, AppSpacing.xs, 4),
      child: Material(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : colors.surface,
        borderRadius: AppRadius.small,
        clipBehavior: lightweightTap ? Clip.none : Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.small,
          splashFactory: lightweightTap ? NoSplash.splashFactory : null,
          highlightColor: lightweightTap ? Colors.transparent : null,
          focusColor: lightweightTap ? Colors.transparent : null,
          hoverColor: lightweightTap
              ? colors.surfaceMuted.withValues(alpha: 0.7)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.cloud,
                          size: 22,
                          color: Color(0xFF0EA5E9),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: checking
                              ? colors.warning
                              : !configured
                              ? colors.textTertiary.withValues(alpha: 0.4)
                              : online
                              ? colors.success
                              : colors.warning,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surface, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.chatS3RelayTitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        checking
                            ? l10n.chatS3StatusChecking
                            : !configured
                            ? l10n.chatS3StatusNotConfigured
                            : online
                            ? l10n.chatS3StatusOnlineSendAll
                            : l10n.chatS3StatusUnavailableCheck,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
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

/// Subscribes only to this [device]'s reach row so probe updates for other peers
/// do not rebuild this list tile.
class _DeviceListReachRow extends ConsumerWidget {
  const _DeviceListReachRow({
    super.key,
    required this.device,
    required this.isMyDevice,
    required this.selected,
    required this.onTap,
  });

  final DeviceDto device;
  final bool isMyDevice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(
      deviceReachabilityProvider.select(
        (m) => m[device.deviceId] ?? DeviceReachDetail.offlineDetail,
      ),
    );
    final reachStatus = detail.uiReachStatus;
    return DeviceConversationItem(
      device: device,
      isMyDevice: isMyDevice,
      selected: selected,
      reachStatus: reachStatus,
      onTap: onTap,
    );
  }
}

Future<void> _showWebDavConnectionMenu(
  BuildContext context,
  WidgetRef ref,
  WebDavConnectionSummary conn,
) async {
  final theme = Theme.of(context);
  final colors = context.appColors;
  final l10n = AppLocalizations.of(context);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.surface,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(LucideIcons.pencil, color: theme.colorScheme.primary),
            title: Text(l10n.webdavEditConnection),
            onTap: () async {
              Navigator.pop(ctx);
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => WebDavConnectionScreen(connectionId: conn.id),
                ),
              );
              if (ok == true) {
                await ref.read(webDavConnectionsProvider.notifier).refresh();
              }
            },
          ),
          ListTile(
            leading: Icon(LucideIcons.plugZap, color: colors.success),
            title: Text(l10n.webdavTestConnection),
            onTap: () async {
              Navigator.pop(ctx);
              try {
                final result = await testWebDavConnection(conn.id);
                if (!context.mounted) return;
                AppToast.show(
                  context,
                  message: result.ok ? l10n.webdavTestSuccess : result.message,
                );
              } catch (e) {
                if (!context.mounted) return;
                AppToast.show(context, message: l10n.webdavTestFailed('$e'));
              }
            },
          ),
          ListTile(
            leading: Icon(LucideIcons.trash2, color: colors.danger),
            title: Text(
              l10n.webdavDeleteConnection,
              style: TextStyle(color: colors.danger),
            ),
            onTap: () async {
              Navigator.pop(ctx);
              final ok = await AppConfirmDialog.show(
                context,
                title: l10n.webdavDeleteConnectionTitle,
                content: l10n.webdavDeleteConnectionBody(conn.name),
                confirmLabel: l10n.confirm,
                icon: LucideIcons.trash2,
                isDanger: true,
              );
              if (!ok) return;
              try {
                await deleteWebDavConnection(conn.id);
                await WebDavCredentialStore.instance.remove(conn.id);
                await ref.read(webDavConnectionsProvider.notifier).refresh();
                if (!context.mounted) return;
                AppToast.show(context, message: l10n.webdavDeletedToast);
              } catch (e) {
                if (!context.mounted) return;
                AppToast.show(context, message: l10n.webdavDeleteFailed('$e'));
              }
            },
          ),
        ],
      ),
    ),
  );
}

class _DevicePanelRefreshButton extends StatelessWidget {
  const _DevicePanelRefreshButton({
    required this.probing,
    required this.onRefresh,
    required this.tooltip,
    required this.iconSize,
    this.iconColor,
  });

  final bool probing;
  final Future<void> Function()? onRefresh;
  final String tooltip;
  final double iconSize;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final resolvedColor = iconColor ?? colors.textSecondary;
    return IconButton(
      icon: probing
          ? BusyStatusIndicator(
              size: iconSize * 0.875,
              strokeWidth: 1.5,
              color: resolvedColor,
            )
          : Icon(
              LucideIcons.refreshCw,
              size: iconSize,
              color: iconColor,
            ),
      onPressed: probing || onRefresh == null ? null : onRefresh,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
    );
  }
}
