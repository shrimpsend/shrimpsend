import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api/api.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/webdav_provider.dart';
import '../services/webdav_client.dart';
import '../ui/app_ui.dart';
import '../utils/file_utils.dart';
import '../utils/toast.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/file_icon_widget.dart';

class WebDavBrowserScreen extends ConsumerStatefulWidget {
  final WebDavConnectionSummary connection;

  const WebDavBrowserScreen({super.key, required this.connection});

  @override
  ConsumerState<WebDavBrowserScreen> createState() => _WebDavBrowserScreenState();
}

class _WebDavBrowserScreenState extends ConsumerState<WebDavBrowserScreen> {
  WebDavClient? _client;
  List<WebDavEntry> _entries = [];
  String _relativePath = '';
  bool _loading = true;
  String? _error;
  bool _showSearch = false;
  String _searchQuery = '';
  bool _selectionMode = false;
  final Set<String> _selectedPaths = {};
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final creds = await resolveWebDavCredentials(widget.connection.id);
      _client = WebDavClient(creds);
      await _loadDirectory('');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _loadDirectory(String relativePath) async {
    final client = _client;
    if (client == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _selectionMode = false;
      _selectedPaths.clear();
    });
    try {
      final list = await client.listDirectory(relativePath);
      if (!mounted) return;
      setState(() {
        _relativePath = relativePath;
        _entries = list;
        _loading = false;
      });
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

  Future<void> _openEntry(WebDavEntry entry) async {
    if (entry.isDirectory) {
      await _loadDirectory(entry.path);
      return;
    }
    await _downloadEntries([entry]);
  }

  Future<void> _downloadEntries(List<WebDavEntry> entries) async {
    final client = _client;
    if (client == null) return;
    final l10n = AppLocalizations.of(context);
    final dir = await getTemporaryDirectory();
    final files = <XFile>[];
    try {
      for (final entry in entries) {
        if (entry.isDirectory) continue;
        final localPath = p.join(dir.path, entry.name);
        await client.downloadFile(entry.path, localPath);
        files.add(XFile(localPath));
      }
      if (!mounted || files.isEmpty) return;
      if (files.length == 1) {
        await Share.shareXFiles([files.first], text: files.first.name);
      } else {
        await Share.shareXFiles(files);
      }
      if (!mounted) return;
      AppToast.show(context, message: l10n.webdavDownloadDone);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: l10n.webdavDownloadFailed('$e'));
    }
  }

  Future<void> _deleteSelected() async {
    final client = _client;
    if (client == null || _selectedPaths.isEmpty) return;
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
        await client.deleteResource(path);
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
    final client = _client;
    if (client == null) return;
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
      await client.moveResource(entry.path, dest);
      await _loadDirectory(_relativePath);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: l10n.webdavRenameFailed('$e'));
    }
  }

  Future<void> _createFolder() async {
    final client = _client;
    if (client == null) return;
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
      await client.createDirectory(path);
      await _loadDirectory(_relativePath);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: l10n.webdavCreateFolderFailed('$e'));
    }
  }

  Future<void> _uploadFile() async {
    final client = _client;
    if (client == null) return;
    final l10n = AppLocalizations.of(context);
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    try {
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null && file.path == null) continue;
        final data = bytes ?? await File(file.path!).readAsBytes();
        final remote = _relativePath.isEmpty
            ? file.name
            : '$_relativePath/${file.name}';
        await client.uploadFile(remote, data);
      }
      await _loadDirectory(_relativePath);
      if (!mounted) return;
      AppToast.show(context, message: l10n.webdavUploadDone);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: l10n.webdavUploadFailed('$e'));
    }
  }

  void _showEntryMenu(WebDavEntry entry) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.appColors.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!entry.isDirectory)
              ListTile(
                leading: const Icon(LucideIcons.download),
                title: Text(l10n.webdavActionDownload),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadEntries([entry]);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.connection.name),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? LucideIcons.x : LucideIcons.search),
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchQuery = '';
                _searchController.clear();
              }
            }),
          ),
          IconButton(
            icon: Icon(_selectionMode ? LucideIcons.x : LucideIcons.checkSquare),
            onPressed: () => setState(() {
              _selectionMode = !_selectionMode;
              _selectedPaths.clear();
            }),
          ),
        ],
        bottom: _showSearch
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: l10n.webdavSearchHint,
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  ),
                ),
              )
            : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
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
                      Icon(LucideIcons.chevronRight, size: 14, color: colors.textTertiary),
                      _BreadcrumbChip(
                        label: _breadcrumbSegments[i],
                        onTap: () {
                          final path = _breadcrumbSegments.sublist(0, i + 1).join('/');
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
                            onPressed: _init,
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
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: _visibleEntries.length,
                      itemBuilder: (context, index) {
                        final entry = _visibleEntries[index];
                        final selected = _selectedPaths.contains(entry.path);
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
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : colors.textTertiary,
                                )
                              : IconButton(
                                  icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
                                  onPressed: () => _showEntryMenu(entry),
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
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton(
              onPressed: _showAddSheet,
              child: const Icon(LucideIcons.plus),
            ),
      bottomNavigationBar: _selectionMode && _selectedPaths.isNotEmpty
          ? SafeArea(
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
                      icon: Icon(LucideIcons.trash2, color: colors.danger),
                      onPressed: _deleteSelected,
                    ),
                  ],
                ),
              ),
            )
          : null,
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
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      labelStyle: theme.textTheme.bodySmall,
    );
  }
}
