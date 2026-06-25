import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pending_file_entry.dart';

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
      return PendingFilesLoadResult(entries: [], droppedMissing: 0);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return PendingFilesLoadResult(entries: [], droppedMissing: 0);
      }
      final out = <PendingFileEntry>[];
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
        final relativeSubPath = e['relativeSubPath'] as String?;
        out.add(
          PendingFileEntry.fromPlatformFile(
            PlatformFile(name: name, path: path, size: effectiveSize),
            relativeSubPath: relativeSubPath,
          ),
        );
      }
      return PendingFilesLoadResult(entries: out, droppedMissing: dropped);
    } catch (_) {
      return PendingFilesLoadResult(entries: [], droppedMissing: 0);
    }
  }

  static Future<void> save(List<PendingFileEntry> entries) async {
    final p = await SharedPreferences.getInstance();
    final list = <Map<String, Object?>>[];
    for (final entry in entries) {
      final f = entry.file;
      final path = f.path;
      if (path == null || path.isEmpty) continue;
      if (!await File(path).exists()) continue;
      list.add(
        <String, Object?>{
          'path': path,
          'name': f.name,
          'size': f.size,
          if (entry.relativeSubPath != null &&
              entry.relativeSubPath!.isNotEmpty)
            'relativeSubPath': entry.relativeSubPath,
        },
      );
    }
    await p.setString(_key, jsonEncode(list));
  }

  /// Legacy helper for code paths that only have [PlatformFile] lists.
  static Future<void> savePlatformFiles(List<PlatformFile> files) async {
    await save(
      files.map((f) => PendingFileEntry.fromPlatformFile(f)).toList(),
    );
  }

  static Future<PendingFilesLoadResult> loadLegacyPlatformFiles() async {
    return load();
  }
}

class PendingFilesLoadResult {
  final List<PendingFileEntry> entries;
  /// 解析失败、缺字段或磁盘上文件已不存在而丢弃的条数。
  final int droppedMissing;

  PendingFilesLoadResult({
    required this.entries,
    required this.droppedMissing,
  });

  List<PlatformFile> get files => entries.map((e) => e.file).toList();
}
