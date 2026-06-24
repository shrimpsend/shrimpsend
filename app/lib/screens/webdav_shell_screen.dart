import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/webdav.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/webdav_provider.dart';
import '../services/webdav_session.dart';
import '../services/webdav_transfer_service.dart';
import '../ui/app_ui.dart';
import '../ui/platform_performance.dart';
import 'webdav_files_tab.dart';
import 'webdav_recent_favorites_tab.dart';
import 'webdav_settings_tab.dart';
import 'webdav_transfer_list_screen.dart';

const double _kWebDavBarEdge = 14;
const double _kWebDavBarBottomGap = 12;
const double _kWebDavBarTabWidth = 76;
const int _kWebDavBarTabCount = 3;
const double _kWebDavBarHPadding = 14;
const double _kWebDavBarExtraSpacing = 8;
const double _kWebDavBarExtraSize = 64;
const double _kWebDavBarOuterWidth =
    _kWebDavBarHPadding * 2 +
    _kWebDavBarTabWidth * _kWebDavBarTabCount +
    _kWebDavBarExtraSpacing +
    _kWebDavBarExtraSize;

class WebDavShellScreen extends ConsumerStatefulWidget {
  final WebDavConnectionSummary connection;

  const WebDavShellScreen({super.key, required this.connection});

  @override
  ConsumerState<WebDavShellScreen> createState() => _WebDavShellScreenState();
}

class _WebDavShellScreenState extends ConsumerState<WebDavShellScreen> {
  WebDavClient? _client;
  bool _loading = true;
  String? _error;
  int _tabIndex = 0;
  bool _filesSelectionMode = false;
  int _filesSelectedCount = 0;
  bool _filesSearchVisible = false;
  final _filesTabKey = GlobalKey<WebDavFilesTabState>();
  String _currentPath = '';

  bool get _showAddButton => _tabIndex == 0 && !_filesSelectionMode;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final creds = await resolveWebDavCredentials(widget.connection.id);
      _client = WebDavClient(creds);
      await WebDavTransferService.instance.restorePersistedSnapshots(
        widget.connection.id,
      );
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _onTabSelected(int index) {
    setState(() => _tabIndex = index);
    final connectionId = widget.connection.id;
    if (index == 1) {
      ref.invalidate(webDavRecentProvider(connectionId));
    } else if (index == 2) {
      ref.invalidate(webDavFavoritesProvider(connectionId));
    }
  }

  void _onFilesSelectionChanged(bool selectionMode, int selectedCount) {
    if (_filesSelectionMode == selectionMode &&
        _filesSelectedCount == selectedCount) {
      return;
    }
    setState(() {
      _filesSelectionMode = selectionMode;
      _filesSelectedCount = selectedCount;
    });
  }

  void _onFilesSearchVisibilityChanged(bool visible) {
    if (_filesSearchVisible == visible) return;
    setState(() => _filesSearchVisible = visible);
  }

  void _toggleFilesSearch() {
    _filesTabKey.currentState?.toggleSearch();
  }

  void _exitFilesSelectionMode() {
    _filesTabKey.currentState?.exitSelectionMode();
  }

  void _switchToFilesTab({String? path}) {
    setState(() => _tabIndex = 0);
    if (path != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _filesTabKey.currentState?.navigateToPath(path);
      });
    }
  }

  Future<void> _openFileFromOtherTab(WebDavEntry entry) async {
    _switchToFilesTab();
    await WebDavTransferService.instance.enqueueDownloads(
      client: _client!,
      connection: widget.connection,
      entries: [entry],
    );
  }

  void _openTransferList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WebDavTransferListScreen(
          connection: widget.connection,
        ),
      ),
    );
  }

  void _openSettings() {
    showWebDavSettingsSheet(
      context,
      connection: widget.connection,
      onSwitchConnection: () => Navigator.pop(context),
    );
  }

  void _showAddSheet() {
    if (!_showAddButton) return;
    _filesTabKey.currentState?.showAddSheet();
  }

  Widget _buildPlainBottomBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);

    Widget tab({
      required int index,
      required String label,
      required IconData icon,
    }) {
      final selected = _tabIndex == index;
      final color = selected ? theme.colorScheme.primary : colors.textSecondary;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onTabSelected(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: AppLayout.floatingBottomBarHeight,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colors.surface.withValues(alpha: 0.94),
          colors.background,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colors.border.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.xs),
          tab(
            index: 0,
            label: l10n.webdavTabFiles,
            icon: LucideIcons.folder,
          ),
          tab(
            index: 1,
            label: l10n.webdavTabRecent,
            icon: LucideIcons.clock,
          ),
          tab(
            index: 2,
            label: l10n.webdavTabFavorites,
            icon: LucideIcons.star,
          ),
          const SizedBox(width: _kWebDavBarExtraSpacing),
          Semantics(
            button: true,
            enabled: _showAddButton,
            label: l10n.webdavActionUpload,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showAddButton ? _showAddSheet : null,
              child: Opacity(
                opacity: _showAddButton ? 1 : 0.35,
                child: Container(
                  width: _kWebDavBarExtraSize,
                  height: _kWebDavBarExtraSize,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    LucideIcons.plus,
                    color: theme.colorScheme.onPrimary,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }

  Widget _buildGlassBottomBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);

    return GlassBottomBar(
      tabs: [
        GlassBottomBarTab(
          label: l10n.webdavTabFiles,
          icon: const Icon(LucideIcons.folder),
        ),
        GlassBottomBarTab(
          label: l10n.webdavTabRecent,
          icon: const Icon(LucideIcons.clock),
        ),
        GlassBottomBarTab(
          label: l10n.webdavTabFavorites,
          icon: const Icon(LucideIcons.star),
        ),
      ],
      selectedIndex: _tabIndex,
      onTabSelected: _onTabSelected,
      spacing: _kWebDavBarExtraSpacing,
      extraButton: GlassBottomBarExtraButton(
        label: l10n.webdavActionUpload,
        size: _kWebDavBarExtraSize,
        iconColor: _showAddButton
            ? theme.colorScheme.primary
            : colors.textTertiary,
        icon: Icon(
          LucideIcons.plus,
          color: _showAddButton
              ? theme.colorScheme.primary
              : colors.textTertiary,
          size: 24,
        ),
        onTap: _showAddButton ? _showAddSheet : () {},
      ),
      selectedIconColor: theme.colorScheme.primary,
      unselectedIconColor: colors.textSecondary,
      horizontalPadding: _kWebDavBarHPadding,
      verticalPadding: 0,
      barHeight: AppLayout.floatingBottomBarHeight,
      barBorderRadius: 45,
      tabWidth: _kWebDavBarTabWidth,
      iconSize: 24,
      labelFontSize: 12,
      iconLabelSpacing: 3,
      tabPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      blendAmount: 6,
      indicatorExpansion: 14,
      glowOpacity: 0,
      glowBlurRadius: 0,
      glowSpreadRadius: 0,
      quality: GlassQuality.standard,
      interactionBehavior: GlassInteractionBehavior.none,
      interactionGlowColor: theme.colorScheme.primary,
    );
  }

  Widget _buildFloatingBottomBar(BuildContext context) {
    final bottomInset = AppLayout.floatingBottomSystemInset(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _kWebDavBarEdge,
        0,
        _kWebDavBarEdge,
        bottomInset + _kWebDavBarBottomGap,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = math.min(constraints.maxWidth, _kWebDavBarOuterWidth);
          return Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: barWidth,
              child: AppPlatformPerformance.preferPlainNarrowNavigation
                  ? _buildPlainBottomBar(context)
                  : _buildGlassBottomBar(context),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.connection.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _client == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.connection.name)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'Error', textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: _init,
                  child: Text(l10n.connectionBarRefreshOnlineStatus),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final client = _client!;
    final transferUi = ref.watch(webDavTransferUiProvider(widget.connection.id));
    final activeTransfers = transferUi.activeCount;

    final body = Stack(
      fit: StackFit.expand,
      children: [
        IndexedStack(
          index: _tabIndex,
          children: [
            WebDavFilesTab(
              key: _filesTabKey,
              connection: widget.connection,
              client: client,
              initialPath: _currentPath,
              onPathChanged: (p) => _currentPath = p,
              onSelectionChanged: _onFilesSelectionChanged,
              onSearchVisibilityChanged: _onFilesSearchVisibilityChanged,
            ),
            WebDavRecentTab(
              connection: widget.connection,
              client: client,
              onOpenFolder: (path) => _switchToFilesTab(path: path),
              onOpenFile: _openFileFromOtherTab,
            ),
            WebDavFavoritesTab(
              connection: widget.connection,
              client: client,
              onOpenFolder: (path) => _switchToFilesTab(path: path),
              onOpenFile: _openFileFromOtherTab,
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildFloatingBottomBar(context),
        ),
      ],
    );

    return PopScope(
      canPop: !_filesSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _filesSelectionMode) {
          _exitFilesSelectionMode();
        }
      },
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          title: Text(_appBarTitle(l10n)),
          actions: _buildAppBarActions(l10n, activeTransfers),
        ),
        body: AppPlatformPerformance.preferPlainNarrowNavigation
            ? body
            : GlassBackdropScope(child: body),
      ),
    );
  }

  String _appBarTitle(AppLocalizations l10n) {
    if (_tabIndex == 0 && _filesSelectionMode) {
      return l10n.webdavSelectedCount(_filesSelectedCount);
    }
    if (_tabIndex == 0) {
      return widget.connection.name;
    }
    return _tabTitle(l10n);
  }

  List<Widget> _buildAppBarActions(AppLocalizations l10n, int activeTransfers) {
    if (_tabIndex == 0 && _filesSelectionMode) {
      final filesTab = _filesTabKey.currentState;
      final hasSelection = _filesSelectedCount > 0;
      final canMove = _filesSelectedCount == 1;
      final colors = context.appColors;

      return [
        IconButton(
          icon: const Icon(LucideIcons.download),
          onPressed: hasSelection ? () => filesTab?.downloadSelected() : null,
          tooltip: l10n.webdavActionDownload,
        ),
        IconButton(
          icon: const Icon(LucideIcons.share2),
          onPressed: hasSelection ? () => filesTab?.shareSelected() : null,
          tooltip: l10n.webdavActionShare,
        ),
        IconButton(
          icon: const Icon(LucideIcons.folderInput),
          onPressed: canMove ? () => filesTab?.moveSelected() : null,
          tooltip: l10n.webdavActionMove,
        ),
        IconButton(
          icon: Icon(LucideIcons.trash2, color: colors.danger),
          onPressed: hasSelection ? () => filesTab?.deleteSelected() : null,
          tooltip: l10n.webdavActionDelete,
        ),
        IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: _exitFilesSelectionMode,
          tooltip: l10n.cancel,
        ),
      ];
    }

    return [
      if (_tabIndex == 0)
        IconButton(
          icon: Icon(
            _filesSearchVisible ? LucideIcons.searchX : LucideIcons.search,
          ),
          onPressed: _toggleFilesSearch,
          tooltip: _filesSearchVisible
              ? l10n.fmSearchCloseTooltip
              : l10n.fmSearchTooltip,
        ),
      IconButton(
        icon: activeTransfers > 0
            ? Badge(
                label: Text('$activeTransfers'),
                child: const Icon(LucideIcons.activity),
              )
            : const Icon(LucideIcons.activity),
        onPressed: _openTransferList,
        tooltip: l10n.webdavTransferList,
      ),
      IconButton(
        icon: const Icon(LucideIcons.settings),
        onPressed: _openSettings,
        tooltip: l10n.webdavTabSettings,
      ),
    ];
  }

  String _tabTitle(AppLocalizations l10n) {
    return switch (_tabIndex) {
      1 => l10n.webdavTabRecent,
      2 => l10n.webdavTabFavorites,
      _ => widget.connection.name,
    };
  }
}
