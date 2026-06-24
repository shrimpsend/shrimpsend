import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/webdav.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/received_file_dao.dart';
import '../services/webdav_favorite_dao.dart';
import '../services/webdav_recent_dao.dart';
import '../services/webdav_session.dart';
import '../services/webdav_transfer_service.dart';
import '../ui/app_ui.dart';
import '../utils/file_utils.dart';
import '../utils/open_received_file.dart';
import '../utils/toast.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/file_icon_widget.dart';
import 'webdav_file_detail_screen.dart';

enum WebDavViewMode { list, grid }

class WebDavFilesTab extends StatefulWidget {
  final WebDavConnectionSummary connection;
  final WebDavClient client;
  final String? initialPath;
  final ValueChanged<String>? onPathChanged;
  final VoidCallback? onTransfersChanged;

  const WebDavFilesTab({
    super.key,
    required this.connection,
    required this.client,
    this.initialPath,
    this.onPathChanged,
    this.onTransfersChanged,
  });

  @override
  State<WebDavFilesTab> createState() => WebDavFilesTabState();
}

class WebDavFilesTabState extends State<WebDavFilesTab> {
  static const _prefViewMode = 'webdav_view_mode';

  List<WebDavEntry> _entries = [];
  String _relativePath = '';
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  bool _selectionMode = false;
  final Set<String> _selectedPaths = {};
  final _searchController = TextEditingController();
  WebDavViewMode _viewMode = WebDavViewMode.list;
  final Set<String> _favoritePaths = {};

  @override
  void initState() {
    super.initState();
    _relativePath = widget.initialPath ?? '';
    _loadViewModePref();
    _loadDirectory(_relativePath);
    _loadFavorites();
    WebDavTransferService.instance.addListener(_onTransferUpdate);
  }

  @override
  void dispose() {
    WebDavTransferService.instance.removeListener(_onTransferUpdate);
    _searchController.dispose();
    super.dispose();
  }

  void _onTransferUpdate() {
    widget.onTransfersChanged?.call();
    if (mounted) setState(() {});
  }

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

  Future<void> _loadFavorites() async {
    final list = await WebDavFavoriteDao.instance.listForConnection(_connKey);
    if (!mounted) return;
    setState(() {
      _favoritePaths
        ..clear()
        ..addAll(list.map((e) => e.remotePath));
    });
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
    try {
      final list = await widget.client.listDirectory(relativePath);
      if (!mounted) return;
      setState(() {
        _relativePath = relativePath;
        _entries = list;
        _loading = false;
      });
      widget.onPathChanged?.call(relativePath);
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
  }

  Future<void> _openEntry(WebDavEntry entry) async {
    await _recordAccess(entry);
    if (entry.isDirectory) {
      await _loadDirectory(entry.path);
      return;
    }
    final messageId = webDavMessageId(widget.connection.id, entry.path);
    final record = await ReceivedFileDao.instance.getByMessageId(messageId);
    if (record != null && File(record.readablePath).existsSync() && mounted) {
      await openReceivedFile(context, record.toInfo());
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
    widget.onTransfersChanged?.call();
  }

  Future<void> _openLocalCopy(WebDavEntry entry) async {
    final messageId = webDavMessageId(widget.connection.id, entry.path);
    final record = await ReceivedFileDao.instance.getByMessageId(messageId);
    if (record == null || !mounted) {
      await _downloadEntries([entry]);
      return;
    }
    await openReceivedFile(context, record.toInfo());
  }

  Future<void> _toggleFavorite(WebDavEntry entry) async {
    final isFav = _favoritePaths.contains(entry.path);
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
    await _loadFavorites();
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

  Future<void> _renameEntry(WebDavEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: entry.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.webdavRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.webdavRenameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    controller.dispose();
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
    final controller = TextEditingController(text: '${entry.name}_copy');
    final destName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.webdavActionCopy),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.webdavRenameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    controller.dispose();
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
    final controller = TextEditingController(text: entry.path);
    final destPath = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.webdavActionMove),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.webdavMoveHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    controller.dispose();
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
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.webdavNewFolderTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.webdavNewFolderHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    controller.dispose();
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

  Future<void> _uploadFile() async {
    final l10n = AppLocalizations.of(context);
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final uploads = <({String name, String localPath, int size})>[];
    for (final file in result.files) {
      if (file.path == null) continue;
      final local = File(file.path!);
      if (!local.existsSync()) continue;
      uploads.add((
        name: file.name,
        localPath: file.path!,
        size: file.size > 0 ? file.size : local.lengthSync(),
      ));
    }
    if (uploads.isEmpty) return;
    await WebDavTransferService.instance.enqueueUploads(
      client: widget.client,
      connection: widget.connection,
      relativeDir: _relativePath,
      files: uploads,
    );
    if (!mounted) return;
    AppToast.show(context, message: l10n.webdavTransferQueued(uploads.length));
    widget.onTransfersChanged?.call();
  }

  Future<void> _shareEntries(List<WebDavEntry> entries) async {
    final l10n = AppLocalizations.of(context);
    final files = entries.where((e) => !e.isDirectory).toList();
    if (files.isEmpty) return;
    final xFiles = <XFile>[];
    for (final entry in files) {
      final messageId = webDavMessageId(widget.connection.id, entry.path);
      final record = await ReceivedFileDao.instance.getByMessageId(messageId);
      if (record != null && File(record.readablePath).existsSync()) {
        xFiles.add(XFile(record.readablePath, name: entry.name));
      }
    }
    if (xFiles.isEmpty) {
      if (!mounted) return;
      AppToast.show(context, message: l10n.webdavShareNeedDownload);
      return;
    }
    await Share.shareXFiles(xFiles);
  }

  void _showEntryMenu(WebDavEntry entry) {
    final l10n = AppLocalizations.of(context);
    final isFav = _favoritePaths.contains(entry.path);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.appColors.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                      onFavoriteChanged: _loadFavorites,
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

  void _showAddSheet() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.appColors.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.upload),
              title: Text(l10n.webdavActionUpload),
              onTap: () {
                Navigator.pop(ctx);
                _uploadFile();
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.folderPlus),
              title: Text(l10n.webdavActionNewFolder),
              onTap: () {
                Navigator.pop(ctx);
                _createFolder();
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.webdavSearchHint,
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _viewMode == WebDavViewMode.list
                          ? LucideIcons.layoutGrid
                          : LucideIcons.list,
                      size: 18,
                    ),
                    onPressed: _toggleViewMode,
                    tooltip: _viewMode == WebDavViewMode.list
                        ? l10n.webdavViewGrid
                        : l10n.webdavViewList,
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                ],
              ),
            ),
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              _BreadcrumbChip(label: '/', onTap: () => _loadDirectory('')),
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
                        final path =
                            _breadcrumbSegments.sublist(0, i + 1).join('/');
                        _loadDirectory(path);
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
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
                )
              : _visibleEntries.isEmpty
              ? Center(child: Text(l10n.webdavBrowserEmpty))
              : RefreshIndicator(
                  onRefresh: () => _loadDirectory(_relativePath),
                  child: _viewMode == WebDavViewMode.grid
                      ? GridView.builder(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.md,
                            right: AppSpacing.md,
                            bottom: 88,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: AppSpacing.sm,
                            mainAxisSpacing: AppSpacing.sm,
                          ),
                          itemCount: _visibleEntries.length,
                          itemBuilder: (context, index) =>
                              _buildEntryTile(
                            context,
                            _visibleEntries[index],
                            theme,
                            colors,
                            l10n,
                            grid: true,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: _visibleEntries.length,
                          itemBuilder: (context, index) =>
                              _buildEntryTile(
                            context,
                            _visibleEntries[index],
                            theme,
                            colors,
                            l10n,
                            grid: false,
                          ),
                        ),
                ),
        ),
        if (_selectionMode && _selectedPaths.isNotEmpty)
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: Row(
                children: [
                  Text(l10n.webdavSelectedCount(_selectedPaths.length)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(LucideIcons.download),
                    onPressed: () {
                      final items = _entries
                          .where((e) => _selectedPaths.contains(e.path))
                          .toList();
                      _downloadEntries(items);
                    },
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.share2),
                    onPressed: () {
                      final items = _entries
                          .where((e) => _selectedPaths.contains(e.path))
                          .toList();
                      _shareEntries(items);
                    },
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.folderInput),
                    onPressed: () async {
                      final items = _entries
                          .where((e) => _selectedPaths.contains(e.path))
                          .toList();
                      if (items.length == 1) {
                        await _moveEntry(items.first);
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.trash2, color: colors.danger),
                    onPressed: _deleteSelected,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEntryTile(
    BuildContext context,
    WebDavEntry entry,
    ThemeData theme,
    AppThemeColors colors,
    AppLocalizations l10n, {
    required bool grid,
  }) {
    final selected = _selectedPaths.contains(entry.path);
    final isFav = _favoritePaths.contains(entry.path);

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
          } else {
            _openEntry(entry);
          }
        },
        onLongPress: () {
          setState(() {
            _selectionMode = true;
            _selectedPaths.add(entry.path);
          });
        },
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
                if (isFav)
                  Icon(LucideIcons.star, size: 12, color: colors.warning),
              ],
            ),
          ),
        ),
      );
    }

    return ListTile(
      leading: entry.isDirectory
          ? Icon(LucideIcons.folder, color: colors.warning)
          : FileIconWidget(
              category: getFileCategory(entry.name),
              size: 28,
            ),
      title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        entry.isDirectory
            ? l10n.webdavEntryFolder
            : formatFileSize(entry.size ?? 0),
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.textTertiary,
          fontSize: 11,
        ),
      ),
      trailing: _selectionMode
          ? Icon(
              selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
              color: selected ? theme.colorScheme.primary : colors.textTertiary,
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isFav)
                  Icon(LucideIcons.star, size: 14, color: colors.warning),
                IconButton(
                  icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
                  onPressed: () => _showEntryMenu(entry),
                ),
              ],
            ),
      onTap: () {
        if (_selectionMode) {
          setState(() {
            if (selected) {
              _selectedPaths.remove(entry.path);
            } else {
              _selectedPaths.add(entry.path);
            }
          });
        } else {
          _openEntry(entry);
        }
      },
      onLongPress: () {
        if (!_selectionMode) {
          setState(() {
            _selectionMode = true;
            _selectedPaths.add(entry.path);
          });
        }
      },
    );
  }

  void toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedPaths.clear();
    });
  }

  bool get isSelectionMode => _selectionMode;

  void showAddSheet() => _showAddSheet();
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
