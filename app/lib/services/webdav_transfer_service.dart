import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/webdav.dart';
import '../providers/auth_provider.dart';
import 'file_store.dart';
import 'received_file_dao.dart';
import 'pending_dispatch_bridge.dart';
import 'received_file_index_pipeline.dart';
import 'speed_tracker.dart';
import 'transfer_record.dart';
import 'transfer_state_manager.dart';
import 'transfer_status.dart';
import 'webdav_session.dart';
import 'visible_export_target.dart';

/// Stable received_files key for a WebDAV remote file.
String webDavMessageId(int connectionId, String remotePath) {
  final key = connectionId.toString();
  final hash = Object.hash(key, remotePath);
  return 'webdav_${key}_${hash.abs()}';
}

String webDavConnectionKey(int connectionId) => connectionId.toString();

/// Parent directory of a WebDAV app-relative path (`''` for root).
String webDavRemoteParentPath(String remotePath) {
  if (remotePath.isEmpty) return '';
  final idx = remotePath.lastIndexOf('/');
  if (idx < 0) return '';
  return remotePath.substring(0, idx);
}

typedef WebDavUploadCompleted = void Function({
  required int connectionId,
  required String remotePath,
});

class WebDavTransferSnapshot {
  final String transferId;
  final String fileName;
  final int fileSize;
  final int transferredBytes;
  final String direction;
  final String status;
  final double bytesPerSecond;
  final String? webdavRemotePath;

  const WebDavTransferSnapshot({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.transferredBytes,
    required this.direction,
    required this.status,
    required this.bytesPerSecond,
    this.webdavRemotePath,
  });

  int get progressPercent =>
      fileSize > 0 ? (transferredBytes * 100 ~/ fileSize).clamp(0, 100) : 0;

  bool get isActive =>
      status == TransferStatus.inProgress || status == TransferStatus.paused;
}

class WebDavTransferService extends ChangeNotifier {
  WebDavTransferService._();
  static final instance = WebDavTransferService._();

  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, SpeedTracker> _speedTrackers = {};
  final Map<String, WebDavTransferSnapshot> _snapshots = {};
  final Map<String, int> _pendingProgressBytes = {};
  final Map<String, int> _lastPersistedBytes = {};
  final Map<String, DateTime> _lastProgressPersist = {};
  static const _progressPersistInterval = Duration(milliseconds: 500);
  final Set<WebDavUploadCompleted> _uploadCompletedListeners = {};

  List<WebDavTransferSnapshot> snapshotsFor(String connectionId) {
    return _snapshots.values
        .where((s) => s.transferId.contains(connectionId))
        .toList();
  }

  List<WebDavTransferSnapshot> get allSnapshots =>
      List.unmodifiable(_snapshots.values);

  int activeCountFor(int connectionId) {
    final prefix = 'webdav_${webDavConnectionKey(connectionId)}_';
    return _snapshots.values
        .where((s) => s.isActive && s.transferId.startsWith(prefix))
        .length;
  }

  void addUploadCompletedListener(WebDavUploadCompleted listener) {
    _uploadCompletedListeners.add(listener);
  }

  void removeUploadCompletedListener(WebDavUploadCompleted listener) {
    _uploadCompletedListeners.remove(listener);
  }

  void _notifyUploadCompleted({
    required int connectionId,
    required String remotePath,
  }) {
    for (final listener in _uploadCompletedListeners) {
      listener(connectionId: connectionId, remotePath: remotePath);
    }
  }

  Future<String?> _resolveUserId() async {
    final uid = await getStoredUserId();
    if (uid != null && uid.isNotEmpty) return uid;
    return getOrCreateOfflineUserId();
  }

  Future<void> enqueueDownloads({
    required WebDavClient client,
    required WebDavConnectionSummary connection,
    required List<WebDavEntry> entries,
  }) async {
    for (final entry in entries) {
      if (entry.isDirectory) continue;
      unawaited(
        _runDownload(
          client: client,
          connection: connection,
          entry: entry,
        ),
      );
    }
  }

  Future<void> enqueueUploads({
    required WebDavClient client,
    required WebDavConnectionSummary connection,
    required String relativeDir,
    required List<({String name, String localPath, int size})> files,
  }) async {
    for (final file in files) {
      final remote = relativeDir.isEmpty
          ? file.name
          : '$relativeDir/${file.name}';
      unawaited(
        _runUpload(
          client: client,
          connection: connection,
          remotePath: remote,
          localPath: file.localPath,
          fileName: file.name,
          fileSize: file.size,
        ),
      );
    }
  }

  Future<bool> _runDownload({
    required WebDavClient client,
    required WebDavConnectionSummary connection,
    required WebDavEntry entry,
  }) async {
    final connKey = webDavConnectionKey(connection.id);
    final messageId = webDavMessageId(connection.id, entry.path);
    final transferId =
        'webdav_${connKey}_dl_${entry.path.hashCode.abs()}_${DateTime.now().millisecondsSinceEpoch}';
    final fileSize = entry.size ?? await client.fileSize(entry.path) ?? 0;
    final cancelToken = CancelToken();
    _cancelTokens[transferId] = cancelToken;
    final tracker = SpeedTracker();
    _speedTrackers[transferId] = tracker;

    final record = TransferRecord(
      transferId: transferId,
      fileName: entry.name,
      fileSize: fileSize,
      channel: 'webdav',
      direction: 'download',
      webdavConnectionId: connKey,
      webdavRemotePath: entry.path,
    );
    await TransferStateManager.instance.saveRecord(record);
    _updateSnapshot(
      transferId: transferId,
      fileName: entry.name,
      fileSize: fileSize,
      transferredBytes: 0,
      direction: 'download',
      status: TransferStatus.inProgress,
      tracker: tracker,
      remotePath: entry.path,
    );

    try {
      final savePath = await FileStore.buildReceivePath(messageId, entry.name);
      await client.downloadFile(
        entry.path,
        savePath,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          final totalBytes = total > 0 ? total : fileSize;
          tracker.update(received);
          _scheduleProgressPersist(transferId, received);
          _updateSnapshot(
            transferId: transferId,
            fileName: entry.name,
            fileSize: totalBytes > 0 ? totalBytes : fileSize,
            transferredBytes: received,
            direction: 'download',
            status: TransferStatus.inProgress,
            tracker: tracker,
            remotePath: entry.path,
          );
        },
      );

      await _flushProgressPersist(transferId);

      final uid = await _resolveUserId();
      final exportOk =
          await ReceivedFileIndexPipeline.instance.upsertAndExportInline(
        messageId: messageId,
        upsert: () => ReceivedFileDao.instance.upsert(
          messageId: messageId,
          absPath: savePath,
          cachePath: savePath,
          exportStatus: ExportStatus.pending,
          userId: uid,
          threadKey: 'webdav:$connKey',
          protocol: 'webdav',
          size: fileSize > 0 ? fileSize : WebDavClient.localFileSize(savePath),
          mtime: entry.lastModified,
        ),
      );

      await TransferStateManager.instance.markStatus(
        transferId,
        TransferStatus.completed,
      );
      _snapshots.remove(transferId);
      _cancelTokens.remove(transferId);
      _speedTrackers.remove(transferId);
      _clearProgressPersist(transferId);
      notifyListeners();
      return exportOk;
    } on DioException catch (e) {
      await _flushProgressPersist(transferId);
      if (CancelToken.isCancel(e)) {
        await TransferStateManager.instance.markStatus(
          transferId,
          TransferStatus.paused,
        );
        _updateSnapshot(
          transferId: transferId,
          fileName: entry.name,
          fileSize: fileSize,
          transferredBytes: record.transferredBytes,
          direction: 'download',
          status: TransferStatus.paused,
          tracker: tracker,
          remotePath: entry.path,
        );
      } else {
        await TransferStateManager.instance.markStatus(
          transferId,
          TransferStatus.failed,
        );
        _snapshots.remove(transferId);
        _cancelTokens.remove(transferId);
        _speedTrackers.remove(transferId);
        _clearProgressPersist(transferId);
        notifyListeners();
      }
      return false;
    } catch (_) {
      await _flushProgressPersist(transferId);
      await TransferStateManager.instance.markStatus(
        transferId,
        TransferStatus.failed,
      );
      _snapshots.remove(transferId);
      _cancelTokens.remove(transferId);
      _speedTrackers.remove(transferId);
      _clearProgressPersist(transferId);
      notifyListeners();
      return false;
    }
  }

  Future<void> _runUpload({
    required WebDavClient client,
    required WebDavConnectionSummary connection,
    required String remotePath,
    required String localPath,
    required String fileName,
    required int fileSize,
  }) async {
    final connKey = webDavConnectionKey(connection.id);
    final transferId =
        'webdav_${connKey}_ul_${remotePath.hashCode.abs()}_${DateTime.now().millisecondsSinceEpoch}';
    final cancelToken = CancelToken();
    _cancelTokens[transferId] = cancelToken;
    final tracker = SpeedTracker();
    _speedTrackers[transferId] = tracker;

    final record = TransferRecord(
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      filePath: localPath,
      channel: 'webdav',
      direction: 'upload',
      webdavConnectionId: connKey,
      webdavRemotePath: remotePath,
    );
    await TransferStateManager.instance.saveRecord(record);
    _updateSnapshot(
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      transferredBytes: 0,
      direction: 'upload',
      status: TransferStatus.inProgress,
      tracker: tracker,
      remotePath: remotePath,
    );

    try {
      await client.uploadFileFromPath(
        remotePath,
        localPath,
        cancelToken: cancelToken,
        onProgress: (sent, total) {
          final totalBytes = total > 0 ? total : fileSize;
          tracker.update(sent);
          _scheduleProgressPersist(transferId, sent);
          _updateSnapshot(
            transferId: transferId,
            fileName: fileName,
            fileSize: totalBytes > 0 ? totalBytes : fileSize,
            transferredBytes: sent,
            direction: 'upload',
            status: TransferStatus.inProgress,
            tracker: tracker,
            remotePath: remotePath,
          );
        },
      );
      await _flushProgressPersist(transferId);
      _notifyUploadCompleted(
        connectionId: connection.id,
        remotePath: remotePath,
      );
      await TransferStateManager.instance.markStatus(
        transferId,
        TransferStatus.completed,
      );
      _snapshots.remove(transferId);
      _cancelTokens.remove(transferId);
      _speedTrackers.remove(transferId);
      _clearProgressPersist(transferId);
      notifyListeners();
      PendingDispatchBridge.notifySettled(localPath, success: true);
    } on DioException catch (e) {
      await _flushProgressPersist(transferId);
      if (CancelToken.isCancel(e)) {
        await TransferStateManager.instance.markStatus(
          transferId,
          TransferStatus.paused,
        );
        _updateSnapshot(
          transferId: transferId,
          fileName: fileName,
          fileSize: fileSize,
          transferredBytes: record.transferredBytes,
          direction: 'upload',
          status: TransferStatus.paused,
          tracker: tracker,
          remotePath: remotePath,
        );
        PendingDispatchBridge.notifySettled(localPath, success: false);
      } else {
        await TransferStateManager.instance.markStatus(
          transferId,
          TransferStatus.failed,
        );
        _snapshots.remove(transferId);
        notifyListeners();
        PendingDispatchBridge.notifySettled(localPath, success: false);
      }
    } catch (_) {
      await TransferStateManager.instance.markStatus(
        transferId,
        TransferStatus.failed,
      );
      _snapshots.remove(transferId);
      notifyListeners();
      PendingDispatchBridge.notifySettled(localPath, success: false);
    } finally {
      _cancelTokens.remove(transferId);
      _speedTrackers.remove(transferId);
      _clearProgressPersist(transferId);
    }
  }

  Future<void> pause(String transferId) async {
    _cancelTokens[transferId]?.cancel();
  }

  Future<void> pauseAll(int connectionId) async {
    final prefix = 'webdav_${webDavConnectionKey(connectionId)}_';
    for (final id in _cancelTokens.keys.toList()) {
      if (id.startsWith(prefix)) {
        await pause(id);
      }
    }
  }

  Future<void> resumeDownload({
    required WebDavClient client,
    required WebDavConnectionSummary connection,
    required TransferRecord record,
  }) async {
    if (record.webdavRemotePath == null) return;
    final entry = WebDavEntry(
      name: record.fileName,
      path: record.webdavRemotePath!,
      isDirectory: false,
      size: record.fileSize,
    );
    await TransferStateManager.instance.removeRecord(record.transferId);
    _snapshots.remove(record.transferId);
    await _runDownload(
      client: client,
      connection: connection,
      entry: entry,
    );
  }

  Future<void> resumeUpload({
    required WebDavClient client,
    required WebDavConnectionSummary connection,
    required TransferRecord record,
  }) async {
    if (record.webdavRemotePath == null || record.filePath == null) return;
    await TransferStateManager.instance.removeRecord(record.transferId);
    _snapshots.remove(record.transferId);
    await _runUpload(
      client: client,
      connection: connection,
      remotePath: record.webdavRemotePath!,
      localPath: record.filePath!,
      fileName: record.fileName,
      fileSize: record.fileSize,
    );
  }

  /// Restores in-progress rows from SQLite after cold start. Does not notify.
  Future<void> restorePersistedSnapshots(int connectionId) async {
    final rows = await TransferStateManager.instance.listWebDavTransfers(
      connectionId: webDavConnectionKey(connectionId),
      activeOnly: true,
    );
    for (final r in rows) {
      if (_snapshots.containsKey(r.transferId)) continue;
      _snapshots[r.transferId] = WebDavTransferSnapshot(
        transferId: r.transferId,
        fileName: r.fileName,
        fileSize: r.fileSize,
        transferredBytes: r.transferredBytes,
        direction: r.direction,
        status: r.status,
        bytesPerSecond: 0,
        webdavRemotePath: r.webdavRemotePath,
      );
    }
  }

  void _scheduleProgressPersist(String transferId, int bytes) {
    _pendingProgressBytes[transferId] = bytes;
    final last = _lastProgressPersist[transferId];
    final lastBytes = _lastPersistedBytes[transferId] ?? 0;
    final now = DateTime.now();
    if (last != null &&
        now.difference(last) < _progressPersistInterval &&
        (bytes - lastBytes).abs() < 256 * 1024) {
      return;
    }
    unawaited(_flushProgressPersist(transferId));
  }

  Future<void> _flushProgressPersist(String transferId) async {
    final bytes = _pendingProgressBytes[transferId];
    if (bytes == null) return;
    if (_lastPersistedBytes[transferId] == bytes) return;
    _lastPersistedBytes[transferId] = bytes;
    _lastProgressPersist[transferId] = DateTime.now();
    await TransferStateManager.instance.updateProgress(transferId, bytes);
  }

  void _clearProgressPersist(String transferId) {
    _pendingProgressBytes.remove(transferId);
    _lastPersistedBytes.remove(transferId);
    _lastProgressPersist.remove(transferId);
  }

  void _updateSnapshot({
    required String transferId,
    required String fileName,
    required int fileSize,
    required int transferredBytes,
    required String direction,
    required String status,
    required SpeedTracker tracker,
    String? remotePath,
  }) {
    _snapshots[transferId] = WebDavTransferSnapshot(
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      transferredBytes: transferredBytes,
      direction: direction,
      status: status,
      bytesPerSecond: tracker.bytesPerSecond,
      webdavRemotePath: remotePath,
    );
    notifyListeners();
  }
}
