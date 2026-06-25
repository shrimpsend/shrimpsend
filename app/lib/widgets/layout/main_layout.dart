import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/api.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/device_provider.dart';
import '../../providers/webdav_provider.dart';
import '../../ui/app_ui.dart';
import '../../services/auth_session_controller.dart';
import 'chat_session_pane_host.dart';
import 'device_list_panel.dart';
import 'device_list_panel_width.dart';
import 'webdav_pane_host.dart';
import '../chat/chat_header.dart';

const double _wideBreakpoint = kDeviceListWideBreakpoint;
const String _keyPanelWidth = 'main_layout_panel_width';
/// Drag hit area centered on the sidebar/chat boundary (does not consume row width).
const double _kPanelDividerHitWidth = 8;

class MainLayout extends ConsumerStatefulWidget {
  final Widget Function() chatContentBuilder;
  final Widget? emptyPlaceholder;
  final bool connected;
  final String deviceName;
  final bool statusCheckDone;
  final bool isLoggedIn;
  final AuthSessionPhase authSessionPhase;
  final VoidCallback onShowSettings;
  final VoidCallback? onSearch;
  final VoidCallback? onScanTap;
  final VoidCallback? onAddWebDavTap;
  final VoidCallback? onFileManager;
  final VoidCallback? onOpenS3Settings;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onLoginTap;

  /// Chat header (device session): session-specific actions, e.g. remove peer device.
  final VoidCallback? onSessionDeviceSettings;

  final bool isSelectionMode;
  final int selectedCount;
  final int totalCount;
  final VoidCallback? onExitSelection;
  final VoidCallback? onToggleSelectAll;
  final VoidCallback? onDeleteSelected;

  /// Mobile home tabs: hide device-list footer row + header file/settings (see bottom bar).
  final bool compactDeviceListChrome;

  /// When set (e.g. from [ChatScreen] after [getOrCreateDeviceId]), used for sidebar
  /// display-code matching before [deviceInfoProvider] finishes loading.
  final String? myDeviceId;

  const MainLayout({
    super.key,
    required this.chatContentBuilder,
    this.emptyPlaceholder,
    required this.connected,
    required this.deviceName,
    this.myDeviceId,
    this.statusCheckDone = true,
    this.isLoggedIn = true,
    this.authSessionPhase = AuthSessionPhase.authenticated,
    required this.onShowSettings,
    this.onSearch,
    this.onScanTap,
    this.onAddWebDavTap,
    this.onFileManager,
    this.onOpenS3Settings,
    this.onRefresh,
    this.onLoginTap,
    this.onSessionDeviceSettings,
    this.isSelectionMode = false,
    this.selectedCount = 0,
    this.totalCount = 0,
    this.onExitSelection,
    this.onToggleSelectAll,
    this.onDeleteSelected,
    this.compactDeviceListChrome = false,
  });

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  double _panelWidth = kDeviceListPanelMinWidth;
  bool _hasCustomPanelWidth = false;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _loadPanelWidth();
  }

  Future<void> _loadPanelWidth() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_keyPanelWidth);
    if (saved != null && mounted) {
      setState(() {
        _hasCustomPanelWidth = true;
        _panelWidth = saved.clamp(
          kDeviceListPanelDragMinWidth,
          kDeviceListPanelDragMaxWidth,
        );
      });
    }
  }

  Future<void> _savePanelWidth(double width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyPanelWidth, width);
  }

  WebDavConnectionSummary? _resolveWebDavConnection(String? selection) {
    final connectionId = parseWebDavConnectionId(selection);
    if (connectionId == null) return null;
    final connections = ref.read(webDavConnectionsProvider).valueOrNull ?? [];
    for (final conn in connections) {
      if (conn.id == connectionId) return conn;
    }
    return null;
  }

  void _clearSelection() {
    ref.read(selectedDeviceIdProvider.notifier).select(null);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDeviceId = ref.watch(selectedDeviceIdProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;

        if (isWide) {
          return _buildWideLayout(
            context,
            selectedDeviceId,
            constraints.maxWidth,
          );
        } else {
          return _buildNarrowLayout(context, selectedDeviceId);
        }
      },
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    String? selectedDeviceId,
    double totalWidth,
  ) {
    final colors = context.appColors;
    final maxAllowed = (totalWidth * 0.6).clamp(
      kDeviceListPanelDragMinWidth,
      kDeviceListPanelDragMaxWidth,
    );
    final effectiveWidth = _resolveEffectivePanelWidth(totalWidth, maxAllowed);
    final webDavConnection = isWebDavSelection(selectedDeviceId)
        ? _resolveWebDavConnection(selectedDeviceId)
        : null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          children: [
            SizedBox(
              width: effectiveWidth,
              child: DeviceListPanel(
                connected: widget.connected,
                deviceName: widget.deviceName,
                myDeviceId: widget.myDeviceId,
                statusCheckDone: widget.statusCheckDone,
                isLoggedIn: widget.isLoggedIn,
                authSessionPhase: widget.authSessionPhase,
                onShowSettings: widget.onShowSettings,
                onSearch: widget.onSearch,
                onScanTap: widget.onScanTap,
                onAddWebDavTap: widget.onAddWebDavTap,
                onFileManager: widget.onFileManager,
                onRefresh: widget.onRefresh,
                onLoginTap: widget.onLoginTap,
                showBottomStatusBar: !widget.compactDeviceListChrome,
                showHeaderFileAndSettings: !widget.compactDeviceListChrome,
                showHeaderRefresh: widget.compactDeviceListChrome,
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: colors.surface,
                child: _buildWideRightPane(context, selectedDeviceId, webDavConnection),
              ),
            ),
          ],
        ),
        Positioned(
          left: effectiveWidth - _kPanelDividerHitWidth / 2,
          top: 0,
          bottom: 0,
          width: _kPanelDividerHitWidth,
          child: _buildDivider(context, colors, maxAllowed),
        ),
      ],
    );
  }

  Widget _buildWideRightPane(
    BuildContext context,
    String? selectedDeviceId,
    WebDavConnectionSummary? webDavConnection,
  ) {
    if (isWebDavSelection(selectedDeviceId)) {
      return _buildWebDavPane(
        context,
        connection: webDavConnection,
        embedded: true,
      );
    }

    if (isChatSelection(selectedDeviceId)) {
      return ChatSessionPaneHost(
        key: const ValueKey('chat_session_pane_host'),
        selectedDeviceId: selectedDeviceId!,
        chatContentBuilder: widget.chatContentBuilder,
        isSelectionMode: widget.isSelectionMode,
        selectedCount: widget.selectedCount,
        totalCount: widget.totalCount,
        onExitSelection: widget.onExitSelection,
        onToggleSelectAll: widget.onToggleSelectAll,
        onDeleteSelected: widget.onDeleteSelected,
        onFileManager: widget.onFileManager,
        onOpenS3Settings: widget.onOpenS3Settings,
        onSessionDeviceSettings: widget.onSessionDeviceSettings,
      );
    }

    return Column(
      children: [
        ChatHeader(
          isSelectionMode: widget.isSelectionMode,
          selectedCount: widget.selectedCount,
          totalCount: widget.totalCount,
          onExitSelection: widget.onExitSelection,
          onToggleSelectAll: widget.onToggleSelectAll,
          onDeleteSelected: widget.onDeleteSelected,
          onFileManager: widget.onFileManager,
          onOpenS3Settings: widget.onOpenS3Settings,
          onSessionDeviceSettings: widget.onSessionDeviceSettings,
        ),
        Expanded(child: _buildEmptyState(context)),
      ],
    );
  }

  Widget _buildDivider(
    BuildContext context,
    AppThemeColors colors,
    double maxAllowed,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          setState(() => _isDragging = true);
        },
        onHorizontalDragUpdate: (details) {
          setState(() {
            _hasCustomPanelWidth = true;
            _panelWidth = (_panelWidth + details.delta.dx).clamp(
              kDeviceListPanelDragMinWidth,
              maxAllowed,
            );
          });
        },
        onHorizontalDragEnd: (_) {
          setState(() => _isDragging = false);
          _savePanelWidth(_panelWidth);
        },
        child: SizedBox(
          width: _kPanelDividerHitWidth,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _isDragging ? 2 : 0.5,
              color: _isDragging ? colors.accentSoft : colors.border,
            ),
          ),
        ),
      ),
    );
  }

  double _resolveEffectivePanelWidth(double totalWidth, double maxAllowed) {
    final base = _hasCustomPanelWidth
        ? _panelWidth
        : resolveDeviceListPanelWidth(totalWidth);
    return base.clamp(kDeviceListPanelDragMinWidth, maxAllowed);
  }

  Widget _buildNarrowLayout(BuildContext context, String? selectedDeviceId) {
    if (isWebDavSelection(selectedDeviceId)) {
      final connection = _resolveWebDavConnection(selectedDeviceId);
      return _buildWebDavPane(
        context,
        connection: connection,
        embedded: false,
        onBack: _clearSelection,
      );
    }

    if (isChatSelection(selectedDeviceId)) {
      final colors = context.appColors;
      return ColoredBox(
        color: colors.surface,
        child: Column(
          children: [
            ChatHeader(
              showBackButton: true,
              onBack: _clearSelection,
              isSelectionMode: widget.isSelectionMode,
              selectedCount: widget.selectedCount,
              totalCount: widget.totalCount,
              onExitSelection: widget.onExitSelection,
              onToggleSelectAll: widget.onToggleSelectAll,
              onDeleteSelected: widget.onDeleteSelected,
              onFileManager: widget.onFileManager,
              onOpenS3Settings: widget.onOpenS3Settings,
              onSessionDeviceSettings: widget.onSessionDeviceSettings,
            ),
            Expanded(child: widget.chatContentBuilder()),
          ],
        ),
      );
    }

    return DeviceListPanel(
      connected: widget.connected,
      deviceName: widget.deviceName,
      myDeviceId: widget.myDeviceId,
      statusCheckDone: widget.statusCheckDone,
      isLoggedIn: widget.isLoggedIn,
      authSessionPhase: widget.authSessionPhase,
      onShowSettings: widget.onShowSettings,
      onSearch: widget.onSearch,
      onScanTap: widget.onScanTap,
      onAddWebDavTap: widget.onAddWebDavTap,
      onFileManager: widget.onFileManager,
      onRefresh: widget.onRefresh,
      onLoginTap: widget.onLoginTap,
      showBottomStatusBar: !widget.compactDeviceListChrome,
      showHeaderFileAndSettings: !widget.compactDeviceListChrome,
      showHeaderRefresh: true,
    );
  }

  Widget _buildWebDavPane(
    BuildContext context, {
    required WebDavConnectionSummary? connection,
    required bool embedded,
    VoidCallback? onBack,
  }) {
    if (connection == null) {
      final l10n = AppLocalizations.of(context);
      final theme = Theme.of(context);
      final colors = context.appColors;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.homeWebDavLoadFailed,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () async {
                await ref.read(webDavConnectionsProvider.notifier).refresh();
                if (!mounted) return;
                final selected = ref.read(selectedDeviceIdProvider);
                if (_resolveWebDavConnection(selected) == null) {
                  _clearSelection();
                }
              },
              child: Text(l10n.homeWebDavRetry),
            ),
          ],
        ),
      );
    }

    return WebDavPaneHost(
      connection: connection,
      embedded: embedded,
      onBack: onBack,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    if (widget.emptyPlaceholder != null) return widget.emptyPlaceholder!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              LucideIcons.messageSquare,
              size: 32,
              color: colors.textTertiary.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppLocalizations.of(context).chatPickDeviceToStart,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
