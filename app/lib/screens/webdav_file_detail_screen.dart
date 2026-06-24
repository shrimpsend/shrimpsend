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
import '../utils/toast.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/file_icon_widget.dart';

class WebDavFileDetailScreen extends ConsumerStatefulWidget {
  final WebDavConnectionSummary connection;
  final WebDavClient client;
  final WebDavEntry entry;
  final bool isFavorite;
  final VoidCallback onDeleted;

  const WebDavFileDetailScreen({
    super.key,
    required this.connection,
    required this.client,
    required this.entry,
    required this.isFavorite,
    required this.onDeleted,
  });

  @override
  ConsumerState<WebDavFileDetailScreen> createState() =>
      _WebDavFileDetailScreenState();
}

class _WebDavFileDetailScreenState extends ConsumerState<WebDavFileDetailScreen> {
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.isFavorite;
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await WebDavFavoriteDao.instance.remove(
        connectionId: webDavConnectionKey(widget.connection.id),
        remotePath: widget.entry.path,
      );
    } else {
      await WebDavFavoriteDao.instance.upsert(
        connectionId: webDavConnectionKey(widget.connection.id),
        entry: widget.entry,
      );
    }
    ref.invalidate(webDavFavoritesProvider(widget.connection.id));
    setState(() => _isFavorite = !_isFavorite);
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final ok = await AppConfirmDialog.show(
      context,
      title: l10n.webdavDeleteConfirmTitle,
      content: l10n.webdavDeleteConfirmBody(1),
      confirmLabel: l10n.confirm,
      icon: LucideIcons.trash2,
      isDanger: true,
    );
    if (!ok || !mounted) return;
    try {
      await widget.client.deleteResource(
        widget.entry.path,
        isDirectory: widget.entry.isDirectory,
      );
      if (!mounted) return;
      widget.onDeleted();
      Navigator.pop(context);
      AppToast.show(context, message: l10n.webdavDeletedToast);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: l10n.webdavDeleteFailed('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);
    final entry = widget.entry;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.webdavActionDetails),
        actions: [
          IconButton(
            icon: Icon(_isFavorite ? LucideIcons.starOff : LucideIcons.star),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: entry.isDirectory
                ? Icon(LucideIcons.folder, size: 64, color: colors.warning)
                : FileIconWidget(
                    category: getFileCategory(entry.name),
                    size: 64,
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(
              entry.name,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _DetailRow(
            label: l10n.webdavDetailType,
            value: entry.isDirectory
                ? l10n.webdavEntryFolder
                : getFileCategory(entry.name).name,
          ),
          if (!entry.isDirectory)
            _DetailRow(
              label: l10n.webdavDetailSize,
              value: formatFileSize(entry.size ?? 0),
            ),
          _DetailRow(
            label: l10n.webdavDetailLocation,
            value: entry.path.isEmpty ? '/' : '/${entry.path}',
          ),
          if (entry.lastModified != null)
            _DetailRow(
              label: l10n.webdavDetailModified,
              value: entry.lastModified!.toLocal().toString().substring(0, 16),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: FilledButton.icon(
            onPressed: _delete,
            icon: const Icon(LucideIcons.trash2),
            label: Text(l10n.webdavActionDelete),
            style: FilledButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
