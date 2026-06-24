import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/webdav.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/webdav_favorite_dao.dart';
import '../services/webdav_recent_dao.dart';
import '../services/webdav_session.dart';
import '../services/webdav_transfer_service.dart';
import '../ui/app_ui.dart';
import '../utils/file_utils.dart';
import '../widgets/file_icon_widget.dart';

class WebDavRecentTab extends StatefulWidget {
  final WebDavConnectionSummary connection;
  final WebDavClient client;
  final void Function(String path) onOpenFolder;
  final Future<void> Function(WebDavEntry entry) onOpenFile;

  const WebDavRecentTab({
    super.key,
    required this.connection,
    required this.client,
    required this.onOpenFolder,
    required this.onOpenFile,
  });

  @override
  State<WebDavRecentTab> createState() => _WebDavRecentTabState();
}

class _WebDavRecentTabState extends State<WebDavRecentTab> {
  List<WebDavRecentRecord> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await WebDavRecentDao.instance.listForConnection(
      webDavConnectionKey(widget.connection.id),
    );
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return Center(child: Text(l10n.webdavRecentEmpty));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final entry = item.toEntry();
          return ListTile(
            leading: entry.isDirectory
                ? Icon(LucideIcons.folder, color: colors.warning)
                : FileIconWidget(
                    category: getFileCategory(entry.name),
                    size: 28,
                  ),
            title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              entry.path.isEmpty ? '/' : entry.path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textTertiary,
                fontSize: 11,
              ),
            ),
            trailing: Text(
              _formatTime(item.accessedAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textTertiary,
                fontSize: 11,
              ),
            ),
            onTap: () async {
              if (entry.isDirectory) {
                widget.onOpenFolder(entry.path);
              } else {
                await widget.onOpenFile(entry);
                await _load();
              }
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day}';
  }
}

class WebDavFavoritesTab extends StatefulWidget {
  final WebDavConnectionSummary connection;
  final WebDavClient client;
  final void Function(String path) onOpenFolder;
  final Future<void> Function(WebDavEntry entry) onOpenFile;

  const WebDavFavoritesTab({
    super.key,
    required this.connection,
    required this.client,
    required this.onOpenFolder,
    required this.onOpenFile,
  });

  @override
  State<WebDavFavoritesTab> createState() => _WebDavFavoritesTabState();
}

class _WebDavFavoritesTabState extends State<WebDavFavoritesTab> {
  List<WebDavFavoriteRecord> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await WebDavFavoriteDao.instance.listForConnection(
      webDavConnectionKey(widget.connection.id),
    );
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _remove(WebDavFavoriteRecord item) async {
    await WebDavFavoriteDao.instance.remove(
      connectionId: webDavConnectionKey(widget.connection.id),
      remotePath: item.remotePath,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return Center(child: Text(l10n.webdavFavoritesEmpty));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final entry = item.toEntry();
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
            trailing: IconButton(
              icon: Icon(LucideIcons.starOff, color: colors.warning, size: 18),
              onPressed: () => _remove(item),
            ),
            onTap: () async {
              if (entry.isDirectory) {
                widget.onOpenFolder(entry.path);
              } else {
                await widget.onOpenFile(entry);
              }
            },
          );
        },
      ),
    );
  }
}
