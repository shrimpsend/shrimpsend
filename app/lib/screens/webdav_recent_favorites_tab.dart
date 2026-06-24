import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/webdav.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/webdav_provider.dart';
import '../services/webdav_favorite_dao.dart';
import '../services/webdav_session.dart';
import '../services/webdav_transfer_service.dart';
import '../ui/app_ui.dart';
import '../utils/file_utils.dart';
import '../widgets/file_icon_widget.dart';

class WebDavRecentTab extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);
    final recentAsync = ref.watch(webDavRecentProvider(connection.id));

    return recentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (items) {
        if (items.isEmpty) {
          return Center(child: Text(l10n.webdavRecentEmpty));
        }
        return RefreshIndicator(
          onRefresh: () =>
              ref.read(webDavRecentProvider(connection.id).notifier).refresh(),
          child: ListView.builder(
            padding: EdgeInsets.only(
              bottom: AppLayout.floatingBottomBarScrollInset(context),
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final entry = item.toEntry();
              return ListTile(
                leading: entry.isDirectory
                    ? Icon(LucideIcons.folder, color: colors.warning)
                    : FileIconWidget(
                        category: getFileCategory(entry.name),
                        size: 28,
                      ),
                title: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
                    onOpenFolder(entry.path);
                  } else {
                    await onOpenFile(entry);
                    ref.invalidate(webDavRecentProvider(connection.id));
                  }
                },
              );
            },
          ),
        );
      },
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

class WebDavFavoritesTab extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);
    final favoritesAsync = ref.watch(webDavFavoritesProvider(connection.id));

    return favoritesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (items) {
        if (items.isEmpty) {
          return Center(child: Text(l10n.webdavFavoritesEmpty));
        }
        return RefreshIndicator(
          onRefresh: () => ref
              .read(webDavFavoritesProvider(connection.id).notifier)
              .refresh(),
          child: ListView.builder(
            padding: EdgeInsets.only(
              bottom: AppLayout.floatingBottomBarScrollInset(context),
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final entry = item.toEntry();
              return ListTile(
                leading: entry.isDirectory
                    ? Icon(LucideIcons.folder, color: colors.warning)
                    : FileIconWidget(
                        category: getFileCategory(entry.name),
                        size: 28,
                      ),
                title: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
                  icon: Icon(
                    LucideIcons.starOff,
                    color: colors.warning,
                    size: 18,
                  ),
                  onPressed: () async {
                    await WebDavFavoriteDao.instance.remove(
                      connectionId: webDavConnectionKey(connection.id),
                      remotePath: item.remotePath,
                    );
                    ref.invalidate(webDavFavoritesProvider(connection.id));
                  },
                ),
                onTap: () async {
                  if (entry.isDirectory) {
                    onOpenFolder(entry.path);
                  } else {
                    await onOpenFile(entry);
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}
