import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../api/webdav.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/webdav_provider.dart';
import '../../services/file_store.dart';
import '../../services/local_received_file_resolver.dart';
import '../../services/received_file_dao.dart';
import '../../services/webdav_favorite_dao.dart';
import '../../services/webdav_recent_dao.dart';
import '../../services/webdav_session.dart';
import '../../services/webdav_transfer_service.dart';
import '../../utils/file_utils.dart';
import '../../utils/open_received_file.dart';
import '../../utils/toast.dart';
import '../../widgets/app_confirm_dialog.dart';
import 'webdav_browsable_tab.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

typedef WebDavListChangedCallback = Future<void> Function();

class WebDavEntryActions {
  WebDavEntryActions({
    required this.client,
    required this.connection,
    required this.connKey,
    required this.ref,
    required this.context,
    required this.getLocalPathByRemotePath,
    required this.onListChanged,
    this.onOpenDirectory,
  });

  final WebDavClient client;
  final WebDavConnectionSummary connection;
  final String connKey;
  final WidgetRef ref;
  final BuildContext context;
  final Map<String, String?> Function() getLocalPathByRemotePath;
  final WebDavListChangedCallback onListChanged;
  final Future<void> Function(WebDavEntry entry)? onOpenDirectory;

  Future<ReceivedFileInfo?> resolveLocalFileInfo(WebDavEntry entry) async {
    final localMap = getLocalPathByRemotePath();
    final messageId = webDavMessageId(connection.id, entry.path);
    final localPath =
        localMap[entry.path] ??
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
      threadKey: 'webdav:$connKey',
    );
  }

  Future<void> recordAccess(WebDavEntry entry) async {
    await WebDavRecentDao.instance.recordAccess(
      connectionId: connKey,
      entry: entry,
    );
    ref.invalidate(webDavRecentProvider(connection.id));
  }

  Future<void> syncDaoAfterDelete(String remotePath) async {
    await WebDavRecentDao.instance.removeByPath(
      connectionId: connKey,
      remotePath: remotePath,
    );
    await WebDavFavoriteDao.instance.removeByPath(
      connectionId: connKey,
      remotePath: remotePath,
    );
    ref.invalidate(webDavRecentProvider(connection.id));
    ref.invalidate(webDavFavoritesProvider(connection.id));
  }

  Future<void> syncDaoAfterPathChange({
    required String oldPath,
    required WebDavEntry newEntry,
  }) async {
    await WebDavRecentDao.instance.updatePath(
      connectionId: connKey,
      oldPath: oldPath,
      entry: newEntry,
    );
    await WebDavFavoriteDao.instance.updatePath(
      connectionId: connKey,
      oldPath: oldPath,
      entry: newEntry,
    );
    ref.invalidate(webDavRecentProvider(connection.id));
    ref.invalidate(webDavFavoritesProvider(connection.id));
  }

  Future<void> openEntry(
    WebDavEntry entry, {
    Future<void> Function(String path)? onOpenFolder,
  }) async {
    if (entry.isDirectory) {
      await recordAccess(entry);
      if (onOpenDirectory != null) {
        await onOpenDirectory!(entry);
        return;
      }
      if (onOpenFolder != null) {
        onOpenFolder(entry.path);
        return;
      }
      return;
    }
    await recordAccess(entry);
    final info = await resolveLocalFileInfo(entry);
    if (info != null) {
      await openReceivedFile(context, info);
      return;
    }
    await downloadEntries([entry]);
  }

  Future<void> downloadEntries(List<WebDavEntry> entries) async {
    final l10n = AppLocalizations.of(context);
    final files = entries.where((e) => !e.isDirectory).toList();
    if (files.isEmpty) return;
    for (final e in files) {
      await recordAccess(e);
    }
    await WebDavTransferService.instance.enqueueDownloads(
      client: client,
      connection: connection,
      entries: files,
    );
    AppToast.show(context, message: l10n.webdavTransferQueued(files.length));
  }

  Future<void> openLocalCopy(WebDavEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final info = await resolveLocalFileInfo(entry);
    if (info == null) {
      AppToast.show(context, message: l10n.webdavShareNeedDownload);
      return;
    }
    await openReceivedFile(context, info);
  }

  Future<void> toggleFavorite(WebDavEntry entry) async {
    final favoritesAsync = ref.read(webDavFavoritesProvider(connection.id));
    final favoritePaths = favoritesAsync.maybeWhen(
      data: (list) => list.map((e) => e.remotePath).toSet(),
      orElse: () => <String>{},
    );
    final isFav = favoritePaths.contains(entry.path);
    if (isFav) {
      await WebDavFavoriteDao.instance.remove(
        connectionId: connKey,
        remotePath: entry.path,
      );
    } else {
      await WebDavFavoriteDao.instance.upsert(
        connectionId: connKey,
        entry: entry,
      );
    }
    ref.invalidate(webDavFavoritesProvider(connection.id));
  }

  Future<void> deleteEntries(List<WebDavEntry> entries) async {
    if (entries.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final ok = await AppConfirmDialog.show(
      context,
      title: l10n.webdavDeleteConfirmTitle,
      content: l10n.webdavDeleteConfirmBody(entries.length),
      confirmLabel: l10n.confirm,
      icon: LucideIcons.trash2,
      isDanger: true,
    );
    if (!ok) return;
    try {
      for (final entry in entries) {
        await client.deleteResource(
          entry.path,
          isDirectory: entry.isDirectory,
        );
        await syncDaoAfterDelete(entry.path);
      }
      await onListChanged();
      AppToast.show(context, message: l10n.webdavDeletedToast);
    } catch (e) {
      AppToast.show(context, message: l10n.webdavDeleteFailed('$e'));
    }
  }

  Future<void> renameEntry(WebDavEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final newName = await showWebDavTextInputDialog(
      context: context,
      title: l10n.webdavRenameTitle,
      hint: l10n.webdavRenameHint,
      initialText: entry.name,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.confirm,
    );
    if (newName == null || newName.isEmpty || newName == entry.name) return;
    try {
      final parent = p.dirname(entry.path);
      final dest = parent == '.' ? newName : '$parent/$newName';
      await client.moveResource(
        entry.path,
        dest,
        isDirectory: entry.isDirectory,
      );
      final newEntry = WebDavEntry(
        name: newName,
        path: dest,
        isDirectory: entry.isDirectory,
        size: entry.size,
        lastModified: entry.lastModified,
      );
      await syncDaoAfterPathChange(oldPath: entry.path, newEntry: newEntry);
      await onListChanged();
    } catch (e) {
      AppToast.show(context, message: l10n.webdavRenameFailed('$e'));
    }
  }

  Future<void> copyEntry(WebDavEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final destName = await showWebDavTextInputDialog(
      context: context,
      title: l10n.webdavActionCopy,
      hint: l10n.webdavRenameHint,
      initialText: '${entry.name}_copy',
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.confirm,
    );
    if (destName == null || destName.isEmpty) return;
    try {
      final parent = p.dirname(entry.path);
      final dest = parent == '.' ? destName : '$parent/$destName';
      await client.copyResource(
        entry.path,
        dest,
        isDirectory: entry.isDirectory,
      );
      await onListChanged();
      AppToast.show(context, message: l10n.webdavCopiedToast);
    } catch (e) {
      AppToast.show(context, message: l10n.webdavCopyFailed('$e'));
    }
  }

  Future<void> moveEntry(WebDavEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final destPath = await showWebDavTextInputDialog(
      context: context,
      title: l10n.webdavActionMove,
      hint: l10n.webdavMoveHint,
      initialText: entry.path,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.confirm,
    );
    if (destPath == null || destPath.isEmpty || destPath == entry.path) return;
    try {
      await client.moveResource(
        entry.path,
        destPath,
        isDirectory: entry.isDirectory,
      );
      final destName = p.basename(destPath);
      final newEntry = WebDavEntry(
        name: destName,
        path: destPath,
        isDirectory: entry.isDirectory,
        size: entry.size,
        lastModified: entry.lastModified,
      );
      await syncDaoAfterPathChange(oldPath: entry.path, newEntry: newEntry);
      await onListChanged();
    } catch (e) {
      AppToast.show(context, message: l10n.webdavMoveFailed('$e'));
    }
  }

  Future<void> shareEntries(List<WebDavEntry> entries) async {
    final l10n = AppLocalizations.of(context);
    final files = entries.where((e) => !e.isDirectory).toList();
    if (files.isEmpty) return;
    final xFiles = <XFile>[];
    for (final entry in files) {
      final info = await resolveLocalFileInfo(entry);
      if (info != null) {
        xFiles.add(XFile(info.path, name: entry.name));
      }
    }
    if (xFiles.isEmpty) {
      AppToast.show(context, message: l10n.webdavShareNeedDownload);
      return;
    }
    await Share.shareXFiles(xFiles);
  }
}
