import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/webdav.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/webdav_provider.dart';
import '../services/local_received_file_resolver.dart';
import '../services/received_file_dao.dart';
import '../services/webdav_favorite_dao.dart';
import '../services/webdav_recent_dao.dart';
import '../services/webdav_session.dart';
import '../services/webdav_transfer_service.dart';
import '../services/file_store.dart';
import '../ui/app_ui.dart';
import '../ui/platform_performance.dart';
import '../utils/file_utils.dart';
import '../utils/open_received_file.dart';
import '../utils/toast.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/file_icon_widget.dart';
import 'webdav_file_detail_screen.dart';

enum WebDavViewMode { list, grid }

typedef WebDavSelectionChangedCallback = void Function(
  bool selectionMode,
  int selectedCount,
);

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

class WebDavFilesTabState extends ConsumerState<WebDavFilesTab> {
  static const _prefViewMode = 'webdav_view_mode';

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
  void initState() {
    super.initState();
    _relativePath = widget.initialPath ?? '';
    _loadViewModePref();
    _loadDirectory(_relativePath);
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

  bool get showSearch => _showSearch;

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

  Future<ReceivedFileInfo?> _resolveLocalFileInfo(WebDavEntry entry) async {
    final messageId = webDavMessageId(widget.connection.id, entry.path);
    final localPath =
        _localPathByRemotePath[entry.path] ??
        await LocalReceivedFileResolver.instance.resolveLocalPath(
          messageId: messageId,
          fileName: entry.name,
          size: entry.size,
        );
    if (localPath == null) return null;

    final record = await ReceivedFileDao.instance.getByMessageId(messageId);
    if (record != null) {
      final info = record.toInfo();
      if (info.path == localPath) return info;
      return ReceivedFileInfo(
        messageId: info.messageId,
        path: localPath,
        displayName: info.displayName,
        protocol: info.protocol,
        size: info.size,
        modified: info.modified,
        createdAt: info.createdAt,
        category: info.category,
        threadKey: info.threadKey,
        s3Key: info.s3Key,
        fromDeviceId: info.fromDeviceId,
        cachePath: info.cachePath,
        visiblePath: info.visiblePath,
        exportStatus: info.exportStatus,
        gallerySaved: info.gallerySaved,
      );
    }

    return ReceivedFileInfo(
      messageId: messageId,
      path: localPath,
      displayName: entry.name,
      protocol: 'webdav',
      size: entry.size ?? File(localPath).lengthSync(),
      modified: entry.lastModified ?? DateTime.now(),
      createdAt: DateTime.now(),
      category: getFileCategory(entry.name),
      threadKey: 'webdav:$_connKey',
    );
  }

  void _notifySelectionChanged() {
    widget.onSelectionChanged?.call(_selectionMode, _selectedPaths.length);
  }

  List<WebDavEntry> get _selectedEntries => _entries
      .where((e) => _selectedPaths.contains(e.path))
      .toList();

  Future<void> _loadViewModePref() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefViewMode);
    if (!mounted) return;
    setState(() {
      _viewMode = raw == 'grid' ? WebDavViewMode.grid : WebDavViewMode.list;
    });
  }

  Future<void> _toggleViewMode() async {
    final next = _viewMode == WebDavViewMode.list
        ? WebDavViewMode.grid
        : WebDavViewMode.list;
    setState(() => _viewMode = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefViewMode,
      next == WebDavViewMode.grid ? 'grid' : 'list',
    );
  }

  String get _connKey => webDavConnectionKey(widget.connection.id);

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

  Future<void> _recordAccess(WebDavEntry entry) async {
    await WebDavRecentDao.instance.recordAccess(
      connectionId: _connKey,
      entry: entry,
    );
    ref.invalidate(webDavRecentProvider(widget.connection.id));
  }

  Future<void> _openEntry(WebDavEntry entry) async {
    if (entry.isDirectory) {
      unawaited(_recordAccess(entry));
      await _loadDirectory(entry.path);
      return;
    }
    await _recordAccess(entry);
    final info = await _resolveLocalFileInfo(entry);
    if (info != null && mounted) {
      await openReceivedFile(context, info);
      return;
    }
    await _downloadEntries([entry]);
  }

  Future<void> _downloadEntries(List<WebDavEntry> entries) async {
    final l10n = AppLocalizations.of(context);
    final files = entries.where((e) => !e.isDirectory).toList();
    if (files.isEmpty) return;
    for (final e in files) {
      await _recordAccess(e);
    }
    await WebDavTransferService.instance.enqueueDownloads(
      client: widget.client,
      connection: widget.connection,
      entries: files,
    );
    if (!mounted) return;
    AppToast.show(context, message: l10n.webdavTransferQueued(files.length));
  }

  Future<void> _openLocalCopy(WebDavEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final info = await _resolveLocalFileInfo(entry);
    if (info == null) {
      if (!mounted) return;
      AppToast.show(context, message: l10n.webdavShareNeedDownload);
      return;
    }
    if (!mounted) return;
    await openReceivedFile(context, info);
  }

  Future<void> _toggleFavorite(WebDavEntry entry) async {
    final favoritesAsync = ref.read(webDavFavoritesProvider(widget.connection.id));
    final favoritePaths = _favoritePathsFrom(favoritesAsync);
    final isFav = favoritePaths.contains(entry.path);
    if (isFav) {
      await WebDavFavoriteDao.instance.remove(
        connectionId: _connKey,
        remotePath: entry.path,
      );
    } else {
      await WebDavFavoriteDao.instance.upsert(
        connectionId: _connKey,
        entry: entry,
      );
    }
    ref.invalidate(webDavFavoritesProvider(widget.connection.id));
  }

  Future<void> _deleteSelected() async {
    if (_selectedPaths.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final ok = await AppConfirmDialog.show(
      context,
      title: l10n.webdavDeleteConfirmTitle,
      content: l10n.webdavDeleteConfirmBody(_selectedPaths.length),
      confirmLabel: l10n.confirm,
      icon: LucideIcons.trash2,
      isDanger: true,
    );
    if (!ok || !mounted) return;
    try {
      for (final path in _selectedPaths) {
        WebDavEntry? entry;
        for (final e in _entries) {
          if (e.path == path) {
            entry = e;
            break;
          }
        }
        await widget.client.deleteResource(
          path,
          isDirectory: entry?.isDirectory ?? false,
        );
      }
      await _loadDirectory(_relativePath);
      if (!mounted) return;
      AppToast.show(context, message: l10n.webdavDeletedToast);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: l10n.webdavDeleteFailed('$e'));
    }
  }

  Future<String?> _showTextInputDialog({
    required String title,
    required String hint,
    String initialText = '',
  }) {
    final l10n = AppLocalizations.of(context);
    return showDialog<String>(
      context: context,
      builder: (ctx) => _WebDavTextInputDialog(
        title: title,
        hint: hint,
        initialText: initialText,
        cancelLabel: l10n.cancel,
        confirmLabel: l10n.confirm,
      ),
    );
  }

  Future<void> _renameEntry(WebDavEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final newName = await _showTextInputDialog(
      title: l10n.webdavRenameTitle,
      hint: l10n.webdavRenameHint,
      initialText: entry.name,
    );
    if (newName == null || newName.isEmpty || newName == entry.name) return;
    try {
      final parent = p.dirname(entry.path);
      final dest = parent == '.' ? newName : '$parent/$newName';
      await widget.client.moveResource(
        entry.path,
        dest,
        isDirectory: entry.isDirectory,
      );
      await _loadDirectory(_relativePath);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: l10n.webdavRenameFailed('$e'));
    }
  }

  Future<void> _copyEntry(WebDavEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final destName = await _showTextInputDialog(
      title: l10n.webdavActionCopy,
      hint: l10n.webdavRenameHint,
      initialText: '${entry.name}_copy',
    );
    if (destName == null || destName.isEmpty) return;
    try {
      final parent = p.dirname(entry.path);
      final dest = parent == '.' ? destName : '$parent/$destName';
      await widget.client.copyResource(
        entry.path,
        dest,
        isDirectory: entry.isDirectory,
      );
      await _loadDirectory(_relativePath);
      if (!mounted) return;
      AppToast.show(context, message: l10n.webdavCopiedToast);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: l10n.webdavCopyFailed('$e'));
    }
  }

  Future<void> _moveEntry(WebDavEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final destPath = await _showTextInputDialog(
      title: l10n.webdavActionMove,
      hint: l10n.webdavMoveHint,
      initialText: entry.path,
    );
    if (destPath == null || destPath.isEmpty || destPath == entry.path) return;
    try {
      await widget.client.moveResource(
        entry.path,
        destPath,
        isDirectory: entry.isDirectory,
      );
      await _loadDirectory(_relativePath);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: l10n.webdavMoveFailed('$e'));
    }
  }

  Future<void> _createFolder() async {
    final l10n = AppLocalizations.of(context);
    final name = await _showTextInputDialog(
      title: l10n.webdavNewFolderTitle,
      hint: l10n.webdavNewFolderHint,
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

  Future<int> uploadPlatformFiles(List<PlatformFile> files) async {
    final uploads = <({String name, String localPath, int size})>[];
    for (final file in files) {
      if (file.path == null) continue;
      final local = File(file.path!);
      if (!local.existsSync()) continue;
      uploads.add((
        name: file.name,
        localPath: file.path!,
        size: file.size > 0 ? file.size : local.lengthSync(),
      ));
    }
    if (uploads.isEmpty) return 0;
    await WebDavTransferService.instance.enqueueUploads(
      client: widget.client,
      connection: widget.connection,
      relativeDir: _relativePath,
      files: uploads,
    );
    return uploads.length;
  }

  String get currentRelativePath => _relativePath;

  Future<void> _shareEntries(List<WebDavEntry> entries) async {
    final l10n = AppLocalizations.of(context);
    final files = entries.where((e) => !e.isDirectory).toList();
    if (files.isEmpty) return;
    final xFiles = <XFile>[];
    for (final entry in files) {
      final info = await _resolveLocalFileInfo(entry);
      if (info != null) {
        xFiles.add(XFile(info.path, name: entry.name));
      }
    }
    if (xFiles.isEmpty) {
      if (!mounted) return;
      AppToast.show(context, message: l10n.webdavShareNeedDownload);
      return;
    }
    await Share.shareXFiles(xFiles);
  }

  void _enterSelectionMode({WebDavEntry? entry}) {
    setState(() {
      _selectionMode = true;
      _selectedPaths.clear();
      if (entry != null) {
        _selectedPaths.add(entry.path);
      }
    });
    _notifySelectionChanged();
  }

  void _showEntryMenu(WebDavEntry entry, Set<String> favoritePaths) {
    final l10n = AppLocalizations.of(context);
    final isFav = favoritePaths.contains(entry.path);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.appColors.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.checkSquare),
              title: Text(l10n.fmMultiSelectMode),
              onTap: () {
                Navigator.pop(ctx);
                _enterSelectionMode(entry: entry);
              },
            ),
            if (!entry.isDirectory) ...[
              ListTile(
                leading: const Icon(LucideIcons.download),
                title: Text(l10n.webdavActionDownload),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadEntries([entry]);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.externalLink),
                title: Text(l10n.webdavActionOpenWith),
                onTap: () {
                  Navigator.pop(ctx);
                  _openLocalCopy(entry);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.share2),
                title: Text(l10n.webdavActionShare),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareEntries([entry]);
                },
              ),
            ],
            ListTile(
              leading: Icon(isFav ? LucideIcons.starOff : LucideIcons.star),
              title: Text(
                isFav ? l10n.webdavActionUnfavorite : l10n.webdavActionFavorite,
              ),
              onTap: () {
                Navigator.pop(ctx);
                _toggleFavorite(entry);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.pencil),
              title: Text(l10n.webdavActionRename),
              onTap: () {
                Navigator.pop(ctx);
                _renameEntry(entry);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.copy),
              title: Text(l10n.webdavActionCopy),
              onTap: () {
                Navigator.pop(ctx);
                _copyEntry(entry);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.folderInput),
              title: Text(l10n.webdavActionMove),
              onTap: () {
                Navigator.pop(ctx);
                _moveEntry(entry);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.info),
              title: Text(l10n.webdavActionDetails),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WebDavFileDetailScreen(
                      connection: widget.connection,
                      client: widget.client,
                      entry: entry,
                      isFavorite: isFav,
                      onDeleted: () => _loadDirectory(_relativePath),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.trash2, color: context.appColors.danger),
              title: Text(
                l10n.webdavActionDelete,
                style: TextStyle(color: context.appColors.danger),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                _selectedPaths
                  ..clear()
                  ..add(entry.path);
                await _deleteSelected();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);
    final favoritePaths = _favoritePathsFrom(
      ref.watch(webDavFavoritesProvider(widget.connection.id)),
    );

    final scrollBottom = AppLayout.floatingBottomBarScrollInset(context);

    Widget buildFileBody() {
      if (_loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: () => _loadDirectory(_relativePath),
                  child: Text(l10n.connectionBarRefreshOnlineStatus),
                ),
              ],
            ),
          ),
        );
      }
      if (_visibleEntries.isEmpty) {
        return Center(child: Text(l10n.webdavBrowserEmpty));
      }
      return RefreshIndicator(
        onRefresh: () => _loadDirectory(_relativePath),
        child: _viewMode == WebDavViewMode.grid
            ? GridView.builder(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.xs,
                  scrollBottom,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: AppSpacing.xs,
                  mainAxisSpacing: AppSpacing.xs,
                ),
                itemCount: _visibleEntries.length,
                itemBuilder: (context, index) => _buildEntryTile(
                  context,
                  _visibleEntries[index],
                  theme,
                  colors,
                  l10n,
                  favoritePaths,
                  grid: true,
                ),
              )
            : ListView.separated(
                padding: EdgeInsets.only(bottom: scrollBottom),
                itemCount: _visibleEntries.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 1,
                  color: colors.border,
                ),
                itemBuilder: (context, index) => _buildEntryTile(
                  context,
                  _visibleEntries[index],
                  theme,
                  colors,
                  l10n,
                  favoritePaths,
                  grid: false,
                ),
              ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: l10n.webdavSearchHint,
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              0,
              AppSpacing.xs,
              0,
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.md),
              ),
              child: ColoredBox(
                color: colors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
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
                                  for (var i = 0;
                                      i < _breadcrumbSegments.length;
                                      i++)
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
                          if (!_selectionMode) ...[
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
                          ],
                        ],
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: colors.border),
                    Expanded(child: buildFileBody()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadedBadge(AppLocalizations l10n, AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.success.withValues(alpha: 0.08),
        border: Border.all(color: colors.success.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        l10n.webdavLocalDownloaded,
        style: TextStyle(
          color: colors.success,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFileMetaRow(
    WebDavEntry entry,
    AppLocalizations l10n,
    ThemeData theme,
    AppThemeColors colors,
  ) {
    final isDownloaded =
        !entry.isDirectory && _localPathByRemotePath[entry.path] != null;
    return Row(
      children: [
        Text(
          entry.isDirectory
              ? l10n.webdavEntryFolder
              : formatFileSize(entry.size ?? 0),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.textTertiary,
            fontSize: 11,
          ),
        ),
        if (isDownloaded) ...[
          const SizedBox(width: AppSpacing.xs),
          _buildDownloadedBadge(l10n, colors),
        ],
      ],
    );
  }

  Widget _buildEntryTile(
    BuildContext context,
    WebDavEntry entry,
    ThemeData theme,
    AppThemeColors colors,
    AppLocalizations l10n,
    Set<String> favoritePaths, {
    required bool grid,
  }) {
    final selected = _selectedPaths.contains(entry.path);
    final isFav = favoritePaths.contains(entry.path);
    final isDownloaded =
        !entry.isDirectory && _localPathByRemotePath[entry.path] != null;

    if (grid) {
      return InkWell(
        onTap: () {
          if (_selectionMode) {
            setState(() {
              if (selected) {
                _selectedPaths.remove(entry.path);
              } else {
                _selectedPaths.add(entry.path);
              }
            });
            _notifySelectionChanged();
          } else {
            _openEntry(entry);
          }
        },
        onLongPress: () => _showEntryMenu(entry, favoritePaths),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                entry.isDirectory
                    ? Icon(LucideIcons.folder, color: colors.warning, size: 32)
                    : FileIconWidget(
                        category: getFileCategory(entry.name),
                        size: 32,
                      ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                if (isDownloaded) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  _buildDownloadedBadge(l10n, colors),
                ],
                if (isFav)
                  Icon(LucideIcons.star, size: 12, color: colors.warning),
              ],
            ),
          ),
        ),
      );
    }

    final lightweightTap = AppPlatformPerformance.preferLightweightTapFeedback;

    return Material(
      color: _selectionMode && selected
          ? theme.colorScheme.primary.withValues(alpha: 0.1)
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_selectionMode) {
            setState(() {
              if (selected) {
                _selectedPaths.remove(entry.path);
              } else {
                _selectedPaths.add(entry.path);
              }
            });
            _notifySelectionChanged();
          } else {
            _openEntry(entry);
          }
        },
        onLongPress: () => _showEntryMenu(entry, favoritePaths),
        splashFactory: lightweightTap ? NoSplash.splashFactory : null,
        highlightColor: lightweightTap ? Colors.transparent : null,
        focusColor: lightweightTap ? Colors.transparent : null,
        hoverColor: lightweightTap
            ? colors.surfaceMuted.withValues(alpha: 0.7)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: entry.isDirectory
                    ? Icon(LucideIcons.folder, color: colors.warning, size: 22)
                    : FileIconWidget(
                        category: getFileCategory(entry.name),
                        size: 28,
                      ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _buildFileMetaRow(entry, l10n, theme, colors),
                  ],
                ),
              ),
              if (_selectionMode)
                Icon(
                  selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                  color:
                      selected ? theme.colorScheme.primary : colors.textTertiary,
                )
              else if (isFav)
                Icon(LucideIcons.star, size: 14, color: colors.warning),
            ],
          ),
        ),
      ),
    );
  }

  void exitSelectionMode() {
    if (!_selectionMode) return;
    setState(() {
      _selectionMode = false;
      _selectedPaths.clear();
    });
    _notifySelectionChanged();
  }

  Future<void> downloadSelected() async {
    await _downloadEntries(_selectedEntries);
  }

  Future<void> shareSelected() async {
    await _shareEntries(_selectedEntries);
  }

  Future<void> moveSelected() async {
    final items = _selectedEntries;
    if (items.length == 1) {
      await _moveEntry(items.first);
    }
  }

  Future<void> deleteSelected() async {
    await _deleteSelected();
  }

  bool get isSelectionMode => _selectionMode;

  int get selectedCount => _selectedPaths.length;
}

class _BreadcrumbChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BreadcrumbChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      labelStyle: theme.textTheme.bodySmall,
    );
  }
}

class _WebDavTextInputDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String initialText;
  final String cancelLabel;
  final String confirmLabel;

  const _WebDavTextInputDialog({
    required this.title,
    required this.hint,
    required this.initialText,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  @override
  State<_WebDavTextInputDialog> createState() => _WebDavTextInputDialogState();
}

class _WebDavTextInputDialogState extends State<_WebDavTextInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
