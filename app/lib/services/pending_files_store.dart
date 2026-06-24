import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 持久化「待发文件箱」中的文件引用（路径 + 元数据）。
///
/// 仅保存含本地路径的项；加载时校验文件仍存在。
final class PendingFilesStore {
  PendingFilesStore._();

  static const _key = 'ultrasend_pending_files_v1';

  static Future<PendingFilesLoadResult> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) {
      return PendingFilesLoadResult(files: [], droppedMissing: 0);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return PendingFilesLoadResult(files: [], droppedMissing: 0);
      }
      final out = <PlatformFile>[];
      var dropped = 0;
      for (final e in decoded) {
        if (e is! Map) {
          dropped++;
          continue;
        }
        final path = e['path'] as String?;
        final name = e['name'] as String?;
        final sizeRaw = e['size'];
        if (path == null || path.isEmpty || name == null || name.isEmpty) {
          dropped++;
          continue;
        }
        final sizeInt = sizeRaw is int
            ? sizeRaw
            : (sizeRaw is num ? sizeRaw.toInt() : 0);
        final file = File(path);
        if (!await file.exists()) {
          dropped++;
          continue;
        }
        var effectiveSize = sizeInt;
        try {
          effectiveSize = await file.length();
        } catch (_) {}
        out.add(
          PlatformFile(name: name, path: path, size: effectiveSize),
        );
      }
      return PendingFilesLoadResult(files: out, droppedMissing: dropped);
    } catch (_) {
      return PendingFilesLoadResult(files: [], droppedMissing: 0);
    }
  }

  static Future<void> save(List<PlatformFile> files) async {
    final p = await SharedPreferences.getInstance();
    final list = <Map<String, Object?>>[];
    for (final f in files) {
      final path = f.path;
      if (path == null || path.isEmpty) continue;
      if (!await File(path).exists()) continue;
      list.add(
        <String, Object?>{
          'path': path,
          'name': f.name,
          'size': f.size,
        },
      );
    }
    await p.setString(_key, jsonEncode(list));
  }
}

class PendingFilesLoadResult {
  final List<PlatformFile> files;
  /// 解析失败、缺字段或磁盘上文件已不存在而丢弃的条数。
  final int droppedMissing;

  PendingFilesLoadResult({
    required this.files,
    required this.droppedMissing,
  });
}
