import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/webdav.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/webdav_provider.dart';
import '../services/local_received_file_resolver.dart';
import '../services/received_file_dao.dart';
import '../services/webdav_favorite_dao.dart';
import '../services/webdav_recent_dao.dart';
import '../services/webdav_session.dart';
import '../services/webdav_transfer_service.dart';
import '../ui/app_ui.dart';
import 'webdav/webdav_browsable_tab.dart';
import 'webdav/webdav_entry_actions.dart';
import 'webdav/webdav_entry_browser.dart';
import 'webdav/webdav_view_mode.dart';

enum WebDavVirtualListKind { recent, favorites }

class WebDavRecentTab extends WebDavVirtualEntryTab {
  WebDavRecentTab({
    super.key,
    required super.connection,
    required super.client,
    required super.onOpenFolder,
    super.onSelectionChanged,
    super.onSearchVisibilityChanged,
  }) : super(kind: WebDavVirtualListKind.recent);
}

class WebDavFavoritesTab extends WebDavVirtualEntryTab {
  WebDavFavoritesTab({
    super.key,
    required super.connection,
    required super.client,
    required super.onOpenFolder,
    super.onSelectionChanged,
    super.onSearchVisibilityChanged,
  }) : super(kind: WebDavVirtualListKind.favorites);
}

class WebDavVirtualEntryTab extends ConsumerStatefulWidget {
  final WebDavVirtualListKind kind;
  final WebDavConnectionSummary connection;
  final WebDavClient client;
  final void Function(String path) onOpenFolder;
  final WebDavSelectionChangedCallback? onSelectionChanged;
  final ValueChanged<bool>? onSearchVisibilityChanged;

  const WebDavVirtualEntryTab({
    super.key,
    required this.kind,
    required this.connection,
    required this.client,
    required this.onOpenFolder,
    this.onSelectionChanged,
    this.onSearchVisibilityChanged,
  });

  @override
  ConsumerState<WebDavVirtualEntryTab> createState() =>
      WebDavVirtualEntryTabState();
}

class WebDavVirtualEntryTabState extends ConsumerState<WebDavVirtualEntryTab>
    implements WebDavBrowsableTabController {
  List<WebDavEntry> _entries = [];
  Map<String, DateTime> _accessedAtByPath = {};
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  bool _showSearch = false;
  bool _selectionMode = false;
  final Set<String> _selectedPaths = {};
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  WebDavViewMode _viewMode = WebDavViewMode.list;
  Map<String, String?> _localPathByRemotePath = {};

  String get _connKey => webDavConnectionKey(widget.connection.id);

  @override
  bool get isSearchVisible => _showSearch;

  @override
  bool get isSelectionMode => _selectionMode;

  @override
  void initState() {
    super.initState();
    unawaited(_loadViewModePref());
    unawaited(_loadEntries());
    ReceivedFileDao.addChangedListener(_onReceivedFilesChanged);
    WebDavTransferService.instance.addListener(_onTransferChanged);
  }

  @override
  void dispose() {
    ReceivedFileDao.removeChangedListener(_onReceivedFilesChanged);
    WebDavTransferService.instance.removeListener(_onTransferChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  WebDavEntryActions _actions() {
    return WebDavEntryActions(
      client: widget.client,
      connection: widget.connection,
      connKey: _connKey,
      ref: ref,
      context: context,
      getLocalPathByRemotePath: () => _localPathByRemotePath,
      onListChanged: _loadEntries,
    );
  }

  void _onReceivedFilesChanged() {
    if (!mounted) return;
    unawaited(_refreshLocalPaths());
  }

  void _onTransferChanged() {
    if (!mounted) return;
    unawaited(_refreshLocalPaths());
  }

  Future<void> _loadViewModePref() async {
    final mode = await loadWebDavViewModePref();
    if (!mounted) return;
    setState(() => _viewMode = mode);
  }

  Future<void> _toggleViewMode() async {
    final next = _viewMode == WebDavViewMode.list
        ? WebDavViewMode.grid
        : WebDavViewMode.list;
    setState(() => _viewMode = next);
    await saveWebDavViewModePref(next);
  }

  Future<void> _loadEntries({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      if (widget.kind == WebDavVirtualListKind.recent) {
        final items = await WebDavRecentDao.instance.listForConnection(_connKey);
        if (!mounted) return;
        _accessedAtByPath = {
          for (final item in items) item.remotePath: item.accessedAt,
        };
        _entries = items.map((e) => e.toEntry()).toList();
      } else {
        final items =
            await WebDavFavoriteDao.instance.listForConnection(_connKey);
        if (!mounted) return;
        _accessedAtByPath = {};
        _entries = items.map((e) => e.toEntry()).toList();
      }
      setState(() => _loading = false);
      unawaited(_refreshLocalPaths(_entries));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _refreshLocalPaths([List<WebDavEntry>? entries]) async {
    final targets = entries ?? _entries;
    if (targets.isEmpty) {
      if (!mounted) return;
      setState(() => _localPathByRemotePath = {});
      return;
    }
    final map = await LocalReceivedFileResolver.instance
        .resolveForWebDavEntries(
          connectionId: widget.connection.id,
          entries: targets,
        );
    if (!mounted) return;
    setState(() => _localPathByRemotePath = map);
  }

  Set<String> _favoritePathsFrom(AsyncValue<List<WebDavFavoriteRecord>> async) {
    return async.maybeWhen(
      data: (list) => list.map((e) => e.remotePath).toSet(),
      orElse: () => <String>{},
    );
  }

  List<WebDavEntry> get _visibleEntries {
    if (_searchQuery.isEmpty) return _entries;
    final q = _searchQuery.toLowerCase();
    return _entries
        .where(
          (e) =>
              e.name.toLowerCase().contains(q) ||
              e.path.toLowerCase().contains(q),
        )
        .toList();
  }

  List<WebDavEntry> get _selectedEntries =>
      _entries.where((e) => _selectedPaths.contains(e.path)).toList();

  void _notifySelectionChanged() {
    widget.onSelectionChanged?.call(_selectionMode, _selectedPaths.length);
  }

  @override
  void toggleSearch() {
    final opening = !_showSearch;
    setState(() => _showSearch = opening);
    widget.onSearchVisibilityChanged?.call(opening);
    if (opening) {
      _searchFocusNode.requestFocus();
    } else {
      _searchFocusNode.unfocus();
      if (_searchQuery.isNotEmpty) {
        _searchController.clear();
        setState(() => _searchQuery = '');
      }
    }
  }

  @override
  void exitSelectionMode() {
    if (!_selectionMode) return;
    setState(() {
      _selectionMode = false;
      _selectedPaths.clear();
    });
    _notifySelectionChanged();
  }

  void _enterSelectionMode({WebDavEntry? entry}) {
    setState(() {
      _selectionMode = true;
      _selectedPaths.clear();
      if (entry != null) _selectedPaths.add(entry.path);
    });
    _notifySelectionChanged();
  }

  void _toggleSelection(WebDavEntry entry) {
    setState(() {
      if (_selectedPaths.contains(entry.path)) {
        _selectedPaths.remove(entry.path);
      } else {
        _selectedPaths.add(entry.path);
      }
    });
    _notifySelectionChanged();
  }

  void _handleEntryTap(WebDavEntry entry) {
    if (_selectionMode) {
      _toggleSelection(entry);
      return;
    }
    if (entry.isDirectory) {
      widget.onOpenFolder(entry.path);
      return;
    }
    unawaited(
      _actions().openEntry(
        entry,
        onOpenFolder: (path) async => widget.onOpenFolder(path),
      ),
    );
  }

  @override
  Future<void> downloadSelected() async {
    await _actions().downloadEntries(_selectedEntries);
  }

  @override
  Future<void> shareSelected() async {
    await _actions().shareEntries(_selectedEntries);
  }

  @override
  Future<void> moveSelected() async {
    final items = _selectedEntries;
    if (items.length == 1) {
      await _actions().moveEntry(items.first);
    }
  }

  @override
  Future<void> deleteSelected() async {
    await _actions().deleteEntries(_selectedEntries);
    exitSelectionMode();
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day}';
  }

  /// Reload list from local DB (e.g. after tab switch or favorite change).
  void refreshEntries({bool showLoading = false}) {
    unawaited(_loadEntries(showLoading: showLoading));
  }

  void _applyFavoriteRecords(List<WebDavFavoriteRecord> items) {
    if (!mounted || widget.kind != WebDavVirtualListKind.favorites) return;
    setState(() {
      _accessedAtByPath = {};
      _entries = items.map((e) => e.toEntry()).toList();
      _loading = false;
      _error = null;
    });
    unawaited(_refreshLocalPaths(_entries));
  }

  void _applyRecentRecords(List<WebDavRecentRecord> items) {
    if (!mounted || widget.kind != WebDavVirtualListKind.recent) return;
    setState(() {
      _accessedAtByPath = {
        for (final item in items) item.remotePath: item.accessedAt,
      };
      _entries = items.map((e) => e.toEntry()).toList();
      _loading = false;
      _error = null;
    });
    unawaited(_refreshLocalPaths(_entries));
  }

  @override
  Widget build(BuildContext context) {
    final connectionId = widget.connection.id;
    if (widget.kind == WebDavVirtualListKind.favorites) {
      ref.listen<AsyncValue<List<WebDavFavoriteRecord>>>(
        webDavFavoritesProvider(connectionId),
        (previous, next) {
          next.whenData(_applyFavoriteRecords);
        },
      );
    } else {
      ref.listen<AsyncValue<List<WebDavRecentRecord>>>(
        webDavRecentProvider(connectionId),
        (previous, next) {
          next.whenData(_applyRecentRecords);
        },
      );
    }

    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);
    final favoritePaths = _favoritePathsFrom(
      ref.watch(webDavFavoritesProvider(widget.connection.id)),
    );
    final scrollBottom = AppLayout.webDavBottomBarScrollInset(context);
    final actions = _actions();
    final emptyMessage = widget.kind == WebDavVirtualListKind.recent
        ? l10n.webdavRecentEmpty
        : l10n.webdavFavoritesEmpty;

    Widget? trailingFor(WebDavEntry entry) {
      if (_selectionMode) return null;
      if (widget.kind == WebDavVirtualListKind.recent) {
        final accessedAt = _accessedAtByPath[entry.path];
        if (accessedAt == null) return null;
        return Text(
          _formatTime(accessedAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.textTertiary,
            fontSize: 11,
          ),
        );
      }
      return null;
    }

    Widget subtitleBuilder(
      BuildContext ctx,
      WebDavEntry entry,
      AppLocalizations loc,
      ThemeData th,
      AppThemeColors cols,
      bool isDownloaded,
    ) {
      if (widget.kind == WebDavVirtualListKind.recent) {
        return Text(
          entry.path.isEmpty ? '/' : entry.path,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: th.textTheme.bodySmall?.copyWith(
            color: cols.textTertiary,
            fontSize: 11,
          ),
        );
      }
      return webDavDefaultFileSubtitleBuilder()(
        ctx,
        entry,
        loc,
        th,
        cols,
        isDownloaded,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_showSearch)
          WebDavSearchField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            hintText: l10n.webdavSearchHint,
            query: _searchQuery,
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            onClear: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          ),
        Expanded(
          child: WebDavEntrySurfaceShell(
            header: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.xxs,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.kind == WebDavVirtualListKind.recent
                          ? l10n.webdavTabRecent
                          : l10n.webdavTabFavorites,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (!_selectionMode)
                    IconButton(
                      icon: Icon(
                        _viewMode == WebDavViewMode.list
                            ? LucideIcons.layoutGrid
                            : LucideIcons.list,
                        size: 18,
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip: _viewMode == WebDavViewMode.list
                          ? l10n.webdavViewGrid
                          : l10n.webdavViewList,
                      onPressed: _toggleViewMode,
                    ),
                ],
              ),
            ),
            body: WebDavEntryListBody(
              loading: _loading,
              error: _error,
              emptyMessage: emptyMessage,
              retryLabel: l10n.connectionBarRefreshOnlineStatus,
              onRetry: () => unawaited(_loadEntries()),
              onRefresh: _loadEntries,
              entries: _visibleEntries,
              viewMode: _viewMode,
              scrollBottom: scrollBottom,
              favoritePaths: favoritePaths,
              localPathByRemotePath: _localPathByRemotePath,
              selectionMode: _selectionMode,
              selectedPaths: _selectedPaths,
              actions: actions,
              connection: widget.connection,
              client: widget.client,
              subtitleBuilder: subtitleBuilder,
              trailingBuilder: trailingFor,
              onEntryTap: _handleEntryTap,
              onEnterSelectionMode: (entry) => _enterSelectionMode(entry: entry),
              onDeleted: _loadEntries,
            ),
          ),
        ),
      ],
    );
  }
}
