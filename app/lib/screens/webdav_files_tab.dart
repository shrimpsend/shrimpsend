import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/webdav.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/webdav_provider.dart';
import '../services/local_received_file_resolver.dart';
import '../services/received_file_dao.dart';
import '../services/webdav_favorite_dao.dart';
import '../services/webdav_cstcloud.dart';
import '../services/webdav_session.dart';
import '../services/webdav_transfer_service.dart';
import '../ui/app_ui.dart';
import '../utils/toast.dart';
import 'webdav/webdav_browsable_tab.dart';
import 'webdav/webdav_entry_actions.dart';
import 'webdav/webdav_entry_browser.dart';
import 'webdav/webdav_view_mode.dart';

export 'webdav/webdav_browsable_tab.dart' show WebDavSelectionChangedCallback;
export 'webdav/webdav_view_mode.dart' show WebDavViewMode;

class WebDavFilesTab extends ConsumerStatefulWidget {
  final WebDavConnectionSummary connection;
  final WebDavClient client;
  final String? initialPath;
  final ValueChanged<String>? onPathChanged;
  final WebDavSelectionChangedCallback? onSelectionChanged;
  final ValueChanged<bool>? onSearchVisibilityChanged;

  const WebDavFilesTab({
    super.key,
    required this.connection,
    required this.client,
    this.initialPath,
    this.onPathChanged,
    this.onSelectionChanged,
    this.onSearchVisibilityChanged,
  });

  @override
  ConsumerState<WebDavFilesTab> createState() => WebDavFilesTabState();
}

class WebDavFilesTabState extends ConsumerState<WebDavFilesTab>
    implements WebDavBrowsableTabController {
  List<WebDavEntry> _entries = [];
  String _relativePath = '';
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

  @override
  bool get isSearchVisible => _showSearch;

  @override
  bool get isSelectionMode => _selectionMode;

  @override
  void initState() {
    super.initState();
    _relativePath = widget.initialPath ?? '';
    unawaited(_loadViewModePref());
    unawaited(_loadDirectory(_relativePath));
    ReceivedFileDao.addChangedListener(_onReceivedFilesChanged);
    WebDavTransferService.instance.addListener(_onTransferChanged);
    WebDavTransferService.instance.addUploadCompletedListener(
      _onUploadCompleted,
    );
  }

  @override
  void dispose() {
    ReceivedFileDao.removeChangedListener(_onReceivedFilesChanged);
    WebDavTransferService.instance.removeListener(_onTransferChanged);
    WebDavTransferService.instance.removeUploadCompletedListener(
      _onUploadCompleted,
    );
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String get _connKey => webDavConnectionKey(widget.connection.id);

  WebDavEntryActions _actions() {
    return WebDavEntryActions(
      client: widget.client,
      connection: widget.connection,
      connKey: _connKey,
      ref: ref,
      context: context,
      getLocalPathByRemotePath: () => _localPathByRemotePath,
      onListChanged: () => _loadDirectory(_relativePath),
      onOpenDirectory: (entry) => _loadDirectory(entry.path),
    );
  }

  void _onUploadCompleted({
    required int connectionId,
    required String remotePath,
  }) {
    if (connectionId != widget.connection.id || !mounted) return;
    if (webDavRemoteParentPath(remotePath) != _relativePath) return;
    unawaited(_loadDirectory(_relativePath));
  }

  void _onReceivedFilesChanged() {
    if (!mounted) return;
    unawaited(_refreshLocalPaths());
  }

  void _onTransferChanged() {
    if (!mounted) return;
    unawaited(_refreshLocalPaths());
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

  void _notifySelectionChanged() {
    widget.onSelectionChanged?.call(_selectionMode, _selectedPaths.length);
  }

  List<WebDavEntry> get _selectedEntries => _entries
      .where((e) => _selectedPaths.contains(e.path))
      .toList();

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

  Set<String> _favoritePathsFrom(AsyncValue<List<WebDavFavoriteRecord>> async) {
    return async.maybeWhen(
      data: (list) => list.map((e) => e.remotePath).toSet(),
      orElse: () => <String>{},
    );
  }

  Future<void> navigateToPath(String path) async {
    await _loadDirectory(path);
  }

  Future<void> _loadDirectory(String relativePath) async {
    setState(() {
      _loading = true;
      _error = null;
      _selectionMode = false;
      _selectedPaths.clear();
    });
    _notifySelectionChanged();
    try {
      final list = await widget.client.listDirectory(relativePath);
      if (!mounted) return;
      setState(() {
        _relativePath = relativePath;
        _entries = list;
        _loading = false;
      });
      widget.onPathChanged?.call(relativePath);
      unawaited(_refreshLocalPaths(list));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<WebDavEntry> get _visibleEntries {
    if (_searchQuery.isEmpty) return _entries;
    final q = _searchQuery.toLowerCase();
    return _entries.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  List<String> get _breadcrumbSegments {
    if (_relativePath.isEmpty) return [];
    return _relativePath.split('/').where((s) => s.isNotEmpty).toList();
  }

  Future<void> _createFolder() async {
    final l10n = AppLocalizations.of(context);
    final name = await showWebDavTextInputDialog(
      context: context,
      title: l10n.webdavNewFolderTitle,
      hint: l10n.webdavNewFolderHint,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.confirm,
    );
    if (name == null || name.isEmpty) return;
    try {
      final path = _relativePath.isEmpty ? name : '$_relativePath/$name';
      await widget.client.createDirectory(path);
      await _loadDirectory(_relativePath);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: l10n.webdavCreateFolderFailed('$e'));
    }
  }

  void queuePlatformFileUploads(List<PlatformFile> files) {
    if (cstCloudWebDavBlocksGeneralUpload(widget.connection.baseUrl)) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      AppToast.show(context, message: l10n.webdavCstCloudUploadNotSupported);
      return;
    }
    final uploads = <({String name, String localPath, int size})>[];
    for (final file in files) {
      final path = file.path;
      if (path == null || path.isEmpty) continue;
      final local = File(path);
      if (!local.existsSync()) continue;
      final diskSize = local.lengthSync();
      if (diskSize <= 0) continue;
      uploads.add((
        name: file.name,
        localPath: path,
        size: diskSize,
      ));
    }
    if (uploads.isEmpty) return;
    unawaited(
      WebDavTransferService.instance.enqueueUploads(
        client: widget.client,
        connection: widget.connection,
        relativeDir: _relativePath,
        files: uploads,
      ),
    );
  }

  String get currentRelativePath => _relativePath;

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
    unawaited(_actions().openEntry(entry));
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final favoritePaths = _favoritePathsFrom(
      ref.watch(webDavFavoritesProvider(widget.connection.id)),
    );
    final scrollBottom = AppLayout.webDavBottomBarScrollInset(context);
    final actions = _actions();

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
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _BreadcrumbChip(
                            label: '/',
                            onTap: () => _loadDirectory(''),
                          ),
                          for (var i = 0; i < _breadcrumbSegments.length; i++)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.chevronRight,
                                  size: 14,
                                  color: colors.textTertiary,
                                ),
                                _BreadcrumbChip(
                                  label: _breadcrumbSegments[i],
                                  onTap: () {
                                    final path = _breadcrumbSegments
                                        .sublist(0, i + 1)
                                        .join('/');
                                    _loadDirectory(path);
                                  },
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (!_selectionMode &&
                      !cstCloudWebDavBlocksGeneralUpload(widget.connection.baseUrl)) ...[
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
                    IconButton(
                      icon: const Icon(LucideIcons.plus, size: 18),
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.webdavActionNewFolder,
                      onPressed: _createFolder,
                    ),
                  ] else if (!_selectionMode) ...[
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
                ],
              ),
            ),
            body: WebDavEntryListBody(
              loading: _loading,
              error: _error,
              emptyMessage: l10n.webdavBrowserEmpty,
              retryLabel: l10n.connectionBarRefreshOnlineStatus,
              onRetry: () => unawaited(_loadDirectory(_relativePath)),
              onRefresh: () => _loadDirectory(_relativePath),
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
              subtitleBuilder: webDavDefaultFileSubtitleBuilder(),
              onEntryTap: _handleEntryTap,
              onEnterSelectionMode: (entry) => _enterSelectionMode(entry: entry),
              onDeleted: () => _loadDirectory(_relativePath),
            ),
          ),
        ),
      ],
    );
  }
}

class _BreadcrumbChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BreadcrumbChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.small,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxs,
          vertical: 2,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
