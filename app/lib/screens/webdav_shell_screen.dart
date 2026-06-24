import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/webdav.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/pending_files_provider.dart';
import '../providers/webdav_provider.dart';
import '../services/webdav_session.dart';
import '../services/webdav_transfer_service.dart';
import '../ui/app_ui.dart';
import '../utils/toast.dart';
import '../widgets/pending_files_bar.dart';
import 'webdav/webdav_browsable_tab.dart';
import 'webdav_files_tab.dart';
import 'webdav_recent_favorites_tab.dart';
import 'webdav_settings_tab.dart';
import 'webdav_transfer_list_screen.dart';

class WebDavShellScreen extends ConsumerStatefulWidget {
  final WebDavConnectionSummary connection;

  const WebDavShellScreen({super.key, required this.connection});

  @override
  ConsumerState<WebDavShellScreen> createState() => _WebDavShellScreenState();
}

class _WebDavShellScreenState extends ConsumerState<WebDavShellScreen>
    with WidgetsBindingObserver {
  WebDavClient? _client;
  bool _loading = true;
  String? _error;
  int _tabIndex = 0;
  bool _selectionMode = false;
  int _selectedCount = 0;
  bool _searchVisible = false;
  final _filesTabKey = GlobalKey<WebDavFilesTabState>();
  final _recentTabKey = GlobalKey<WebDavVirtualEntryTabState>();
  final _favoritesTabKey = GlobalKey<WebDavVirtualEntryTabState>();
  String _currentPath = '';

  bool get _showOutboxButton => !_selectionMode;

  WebDavBrowsableTabController? _activeTabController() {
    return switch (_tabIndex) {
      0 => _filesTabKey.currentState,
      1 => _recentTabKey.currentState,
      2 => _favoritesTabKey.currentState,
      _ => null,
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapPendingFiles());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_reloadPendingFiles());
    }
  }

  Future<void> _bootstrapPendingFiles() async {
    final dropped = await ref.read(pendingFilesProvider.notifier).bootstrap();
    if (!mounted) return;
    if (dropped > 0) {
      AppToast.show(
        context,
        message: AppLocalizations.of(context).chatScreenPendingFilesMissing,
      );
    }
  }

  Future<void> _reloadPendingFiles() async {
    final dropped =
        await ref.read(pendingFilesProvider.notifier).reloadFromStore();
    if (!mounted) return;
    if (dropped > 0) {
      AppToast.show(
        context,
        message: AppLocalizations.of(context).chatScreenPendingFilesMissing,
      );
    }
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
    if (index != _tabIndex) {
      _filesTabKey.currentState?.exitSelectionMode();
      _recentTabKey.currentState?.exitSelectionMode();
      _favoritesTabKey.currentState?.exitSelectionMode();
      for (final tab in <WebDavBrowsableTabController?>[
        _filesTabKey.currentState,
        _recentTabKey.currentState,
        _favoritesTabKey.currentState,
      ]) {
        if (tab != null && tab.isSearchVisible) {
          tab.toggleSearch();
        }
      }
    }
    setState(() {
      _tabIndex = index;
      _selectionMode = false;
      _selectedCount = 0;
      _searchVisible = false;
    });
    final connectionId = widget.connection.id;
    if (index == 1) {
      ref.invalidate(webDavRecentProvider(connectionId));
    } else if (index == 2) {
      ref.invalidate(webDavFavoritesProvider(connectionId));
    }
  }

  void _onTabSelectionChanged(bool selectionMode, int selectedCount) {
    if (_selectionMode == selectionMode && _selectedCount == selectedCount) {
      return;
    }
    setState(() {
      _selectionMode = selectionMode;
      _selectedCount = selectedCount;
    });
  }

  void _onTabSearchVisibilityChanged(bool visible) {
    if (_searchVisible == visible) return;
    setState(() => _searchVisible = visible);
  }

  void _toggleActiveTabSearch() {
    _activeTabController()?.toggleSearch();
  }

  void _exitActiveTabSelectionMode() {
    _activeTabController()?.exitSelectionMode();
  }

  void _switchToFilesTab({String? path}) {
    setState(() => _tabIndex = 0);
    if (path != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _filesTabKey.currentState?.navigateToPath(path);
      });
    }
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

  String _uploadTargetLabel(AppLocalizations l10n) {
    final relativePath = _filesTabKey.currentState?.currentRelativePath ?? '';
    if (relativePath.isEmpty) {
      return l10n.webdavOutboxUploadTarget(widget.connection.name);
    }
    return l10n.webdavOutboxUploadTarget('/$relativePath');
  }

  Future<void> _openOutboxSheet() {
    if (!_showOutboxButton) return Future.value();
    final l10n = AppLocalizations.of(context);
    return showPendingOutboxSheet(
      context,
      showAddFiles: true,
      primaryAction: PendingOutboxPrimaryAction(
        label: l10n.webdavOutboxUpload,
        icon: LucideIcons.upload,
        destinationHint: _uploadTargetLabel(l10n),
        onExecute: (queued) async {
          final filesTab = _filesTabKey.currentState;
          if (filesTab == null) return;
          filesTab.queuePlatformFileUploads(queued);
          if (!mounted) return;
          AppToast.show(
            context,
            message: l10n.webdavTransferQueued(queued.length),
          );
        },
      ),
    );
  }

  Widget _buildWebDavBottomBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);
    final pendingCount = ref.watch(pendingFilesProvider).length;

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
          child: InkWell(
            onTap: () => _onTabSelected(index),
            child: SizedBox(
              height: AppLayout.webDavBottomBarHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 2,
                    width: selected ? 28 : 0,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: colors.surface,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, thickness: 1, color: colors.border),
          SafeArea(
            top: false,
            child: SizedBox(
              height: AppLayout.webDavBottomBarHeight,
              child: Row(
                children: [
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
                  Container(
                    width: 1,
                    height: 28,
                    color: colors.border,
                  ),
                  Semantics(
                    button: true,
                    enabled: _showOutboxButton,
                    label: l10n.webdavOutboxUpload,
                    child: InkWell(
                      onTap: _showOutboxButton ? _openOutboxSheet : null,
                      child: Opacity(
                        opacity: _showOutboxButton ? 1 : 0.35,
                        child: SizedBox(
                          width: 72,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Badge(
                                isLabelVisible: pendingCount > 0,
                                label: Text(
                                  pendingCount > 99 ? '99+' : '$pendingCount',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: Icon(
                                  LucideIcons.upload,
                                  color: theme.colorScheme.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.webdavOutboxUpload,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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

    final body = Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: _tabIndex,
            children: [
              WebDavFilesTab(
                key: _filesTabKey,
                connection: widget.connection,
                client: client,
                initialPath: _currentPath,
                onPathChanged: (p) => _currentPath = p,
                onSelectionChanged: _onTabSelectionChanged,
                onSearchVisibilityChanged: _onTabSearchVisibilityChanged,
              ),
              WebDavRecentTab(
                key: _recentTabKey,
                connection: widget.connection,
                client: client,
                onOpenFolder: (path) => _switchToFilesTab(path: path),
                onSelectionChanged: _onTabSelectionChanged,
                onSearchVisibilityChanged: _onTabSearchVisibilityChanged,
              ),
              WebDavFavoritesTab(
                key: _favoritesTabKey,
                connection: widget.connection,
                client: client,
                onOpenFolder: (path) => _switchToFilesTab(path: path),
                onSelectionChanged: _onTabSelectionChanged,
                onSearchVisibilityChanged: _onTabSearchVisibilityChanged,
              ),
            ],
          ),
        ),
        _buildWebDavBottomBar(context),
      ],
    );

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectionMode) {
          _exitActiveTabSelectionMode();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text(_appBarTitle(l10n)),
          actions: _buildAppBarActions(l10n, activeTransfers),
        ),
        body: body,
      ),
    );
  }

  String _appBarTitle(AppLocalizations l10n) {
    if (_selectionMode) {
      return l10n.webdavSelectedCount(_selectedCount);
    }
    if (_tabIndex == 0) {
      return widget.connection.name;
    }
    return _tabTitle(l10n);
  }

  List<Widget> _buildAppBarActions(AppLocalizations l10n, int activeTransfers) {
    if (_selectionMode) {
      final tab = _activeTabController();
      final hasSelection = _selectedCount > 0;
      final canMove = _selectedCount == 1;
      final colors = context.appColors;

      return [
        IconButton(
          icon: const Icon(LucideIcons.download),
          onPressed: hasSelection ? () => tab?.downloadSelected() : null,
          tooltip: l10n.webdavActionDownload,
        ),
        IconButton(
          icon: const Icon(LucideIcons.share2),
          onPressed: hasSelection ? () => tab?.shareSelected() : null,
          tooltip: l10n.webdavActionShare,
        ),
        IconButton(
          icon: const Icon(LucideIcons.folderInput),
          onPressed: canMove ? () => tab?.moveSelected() : null,
          tooltip: l10n.webdavActionMove,
        ),
        IconButton(
          icon: Icon(LucideIcons.trash2, color: colors.danger),
          onPressed: hasSelection ? () => tab?.deleteSelected() : null,
          tooltip: l10n.webdavActionDelete,
        ),
        IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: _exitActiveTabSelectionMode,
          tooltip: l10n.cancel,
        ),
      ];
    }

    return [
      IconButton(
        icon: Icon(
          _searchVisible ? LucideIcons.searchX : LucideIcons.search,
        ),
        onPressed: _toggleActiveTabSearch,
        tooltip: _searchVisible
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
