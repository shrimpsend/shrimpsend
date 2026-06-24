import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'file_store.dart';
import 'saf_storage_service.dart';

final Logger _logStabilizer = Logger('虾传.pending.stabilizer');

/// Ensures pending outbox entries reference durable local files under [FileStore] cache.
final class PendingFilesPathStabilizer {
  PendingFilesPathStabilizer._();

  static Future<List<PlatformFile>> stabilizeAll(
    List<PlatformFile> incoming, {
    String logSource = 'pending',
    String cacheIdPrefix = 'pending',
  }) async {
    final result = <PlatformFile>[];
    for (final file in incoming) {
      final stabilized = await stabilizeOne(
        file,
        logSource: logSource,
        cacheIdPrefix: cacheIdPrefix,
      );
      if (stabilized != null) result.add(stabilized);
    }
    return result;
  }

  static Future<PlatformFile?> stabilizeOne(
    PlatformFile file, {
    String logSource = 'pending',
    String cacheIdPrefix = 'pending',
  }) async {
    if ((file.path == null || file.path!.isEmpty) && file.bytes != null) {
      return _writeBytesToCache(file, logSource: logSource, cacheIdPrefix: cacheIdPrefix);
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      _logStabilizer.warning('$logSource: skip file without path or bytes: ${file.name}');
      return null;
    }

    final cacheRoot = await FileStore.getCacheDir();
    if (FileStore.isPathUnderDirectory(path, cacheRoot)) {
      return _reuseCachePath(file, path, logSource: logSource);
    }

    if (path.startsWith('content://')) {
      return _copyContentUriToCache(
        file,
        path,
        logSource: logSource,
        cacheIdPrefix: cacheIdPrefix,
      );
    }

    return _copyExternalPathToCache(
      file,
      path,
      logSource: logSource,
      cacheIdPrefix: cacheIdPrefix,
    );
  }

  static Future<PlatformFile?> _writeBytesToCache(
    PlatformFile file, {
    required String logSource,
    required String cacheIdPrefix,
  }) async {
    try {
      final name = file.name.isNotEmpty ? file.name : 'pending_file';
      final messageId = '${cacheIdPrefix}_${const Uuid().v4()}';
      final destPath = await FileStore.buildCachePath(messageId, name);
      await File(destPath).writeAsBytes(file.bytes!);
      final stat = await File(destPath).stat();
      return PlatformFile(name: name, path: destPath, size: stat.size);
    } catch (e, st) {
      _logStabilizer.warning(
        '$logSource: failed to write bytes for ${file.name}: $e',
        e,
        st,
      );
      return null;
    }
  }

  static Future<PlatformFile?> _reuseCachePath(
    PlatformFile file,
    String path, {
    required String logSource,
  }) async {
    try {
      final sourceFile = File(path);
      if (!await sourceFile.exists()) {
        _logStabilizer.warning('$logSource: cache path missing: $path');
        return null;
      }
      final stat = await sourceFile.stat();
      final name = file.name.isNotEmpty ? file.name : p.basename(path);
      return PlatformFile(name: name, path: path, size: stat.size);
    } catch (e, st) {
      _logStabilizer.warning('$logSource: failed to reuse cache path $path: $e', e, st);
      return null;
    }
  }

  static Future<PlatformFile?> _copyContentUriToCache(
    PlatformFile file,
    String uri, {
    required String logSource,
    required String cacheIdPrefix,
  }) async {
    if (!SafStorageService.isSupported) {
      _logStabilizer.warning('$logSource: content URI on unsupported platform: $uri');
      return null;
    }
    final name = file.name.isNotEmpty ? file.name : 'file';
    try {
      final messageId = '${cacheIdPrefix}_${const Uuid().v4()}';
      final destPath = await FileStore.buildCachePath(messageId, name);
      final copied = await SafStorageService.copyFileUriToTargetPath(uri, destPath);
      if (copied == null || copied.isEmpty) {
        _logStabilizer.warning('$logSource: SAF copy failed for $uri');
        return null;
      }
      final stat = await File(destPath).stat();
      _logStabilizer.info('$logSource: content URI copied name=$name dest=$destPath');
      return PlatformFile(name: name, path: destPath, size: stat.size);
    } catch (e, st) {
      _logStabilizer.warning('$logSource: failed to copy content URI $uri: $e', e, st);
      return null;
    }
  }

  static Future<PlatformFile?> _copyExternalPathToCache(
    PlatformFile file,
    String path, {
    required String logSource,
    required String cacheIdPrefix,
  }) async {
    try {
      final sourceFile = File(path);
      if (!await sourceFile.exists()) {
        _logStabilizer.warning('$logSource: file not found: $path');
        return null;
      }
      final originalName = file.name.isNotEmpty ? file.name : p.basename(path);
      if (originalName.isEmpty) {
        _logStabilizer.warning('$logSource: empty name for $path');
        return null;
      }
      final messageId = '${cacheIdPrefix}_${const Uuid().v4()}';
      final destPath = await FileStore.buildCachePath(messageId, originalName);
      await sourceFile.copy(destPath);
      final stat = await File(destPath).stat();
      _logStabilizer.info(
        '$logSource: copied to cache name=$originalName src=$path dest=$destPath',
      );
      return PlatformFile(name: originalName, path: destPath, size: stat.size);
    } catch (e, st) {
      _logStabilizer.warning('$logSource: failed to copy $path: $e', e, st);
      return null;
    }
  }

  static bool isPendingCachePath(String path, String cacheRoot) {
    if (!FileStore.isPathUnderDirectory(path, cacheRoot)) return false;
    final relative = p.relative(p.normalize(path), from: p.normalize(cacheRoot));
    final firstSegment = relative.split(Platform.pathSeparator).firstOrNull;
    return firstSegment != null && firstSegment.startsWith('pending_');
  }

  static Future<void> deletePendingCacheFile(String? path) async {
    if (path == null || path.isEmpty) return;
    final cacheRoot = await FileStore.getCacheDir();
    if (!isPendingCachePath(path, cacheRoot)) return;
    await FileStore.deleteFile(path);
  }

  static Future<void> deletePendingCacheFiles(Iterable<PlatformFile> files) async {
    for (final file in files) {
      await deletePendingCacheFile(file.path);
    }
  }
}
