import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../file_store.dart';
import '../pending_files_path_stabilizer.dart';
import 'share_inbound_payload.dart';

final Logger _logIngest = Logger('虾传.share.ingest');

class ShareIngestPipeline {
  ShareIngestPipeline(this._onSaved);

  final void Function(List<PlatformFile> saved, {required String source}) _onSaved;

  Future<List<PlatformFile>> addPaths(
    List<String> pathStrings, {
    required String source,
  }) async {
    return _ingestPaths(pathStrings, source: source);
  }

  Future<List<PlatformFile>> addAttachments(
    List<ShareAttachment> attachments, {
    required String source,
  }) async {
    final paths = <String>[];
    for (final attachment in attachments) {
      final path = attachment.path;
      if (path != null && path.isNotEmpty) {
        paths.add(path);
      }
    }
    return _ingestPaths(paths, source: source);
  }

  Future<List<PlatformFile>> _ingestPaths(
    List<String> pathStrings, {
    required String source,
  }) async {
    final saved = <PlatformFile>[];
    var anyCopiedToCache = false;
    final cacheRoot = await FileStore.getCacheDir();

    for (final pathStr in pathStrings) {
      if (pathStr.isEmpty) {
        _logIngest.fine('$source: skip empty path');
        continue;
      }
      final originalName = p.basename(pathStr);
      if (originalName.isEmpty && !pathStr.startsWith('content://')) {
        _logIngest.warning('$source: empty basename for path $pathStr');
        continue;
      }

      try {
        final alreadyInCache = FileStore.isPathUnderDirectory(pathStr, cacheRoot);
        final platformFile = await PendingFilesPathStabilizer.stabilizeOne(
          PlatformFile(
            name: originalName.isNotEmpty ? originalName : 'shared_file',
            path: pathStr,
            size: 0,
          ),
          logSource: source,
          cacheIdPrefix: 'share',
        );
        if (platformFile == null) continue;

        if (!alreadyInCache) {
          anyCopiedToCache = true;
          _logIngest.info(
            '$source: copied to cache name=${platformFile.name} '
            'nativeStagingPath=$pathStr cachePath=${platformFile.path} skippedExport=true',
          );
        } else {
          _logIngest.info(
            '$source: reuse cache path name=${platformFile.name} '
            'nativeStagingPath=$pathStr cachePath=${platformFile.path} skippedCopy=true skippedExport=true',
          );
        }
        saved.add(platformFile);
      } catch (e, st) {
        _logIngest.warning('$source: failed to ingest $pathStr: $e', e, st);
      }
    }

    if (saved.isEmpty) {
      _logIngest.warning(
        '$source: ingest produced 0 files (input=${pathStrings.length} path(s))',
      );
    }

    if (saved.isNotEmpty) {
      if (anyCopiedToCache) {
        FileStore.notifyReceiveDirChanged();
      }
      _onSaved(saved, source: source);
    }
    return saved;
  }
}
