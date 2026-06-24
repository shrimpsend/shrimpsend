import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as path_provider;

class SafStorageService {
  SafStorageService._();

  static const _channel = MethodChannel('dev.ultrasend/saf_storage');

  static bool get isSupported => Platform.isAndroid;

  static Future<void> restorePersistedTreeUris() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('restorePersistedTreeUris');
    } catch (_) {}
  }

  static Future<String?> pickSaveTree() async {
    if (!isSupported) return null;
    return _channel.invokeMethod<String>('pickSaveTree');
  }

  static Future<bool> probeWritable(String treeUri) async {
    if (!isSupported) return false;
    final ok = await _channel.invokeMethod<bool>(
      'probeWritable',
      {'treeUri': treeUri},
    );
    return ok ?? false;
  }

  static Future<String> getDisplayName(String treeUri) async {
    if (!isSupported) return treeUri;
    final name = await _channel.invokeMethod<String>(
      'getDisplayName',
      {'treeUri': treeUri},
    );
    return name?.trim().isNotEmpty == true ? name!.trim() : treeUri;
  }

  static Future<SafCopyResult> copyFileToTree({
    required String treeUri,
    required String sourcePath,
    required String displayName,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('SAF storage is Android-only');
    }
    final result = await _channel.invokeMapMethod<String, String?>(
      'copyFileToTree',
      {
        'treeUri': treeUri,
        'sourcePath': sourcePath,
        'displayName': displayName,
      },
    );
    return SafCopyResult(
      displayName: result?['displayName'] ?? displayName,
      uri: result?['uri'],
    );
  }

  static Future<List<SafTreeFileEntry>> listFilesInTree(String treeUri) async {
    if (!isSupported) return const [];
    final result = await _channel.invokeMethod<List<dynamic>>(
      'listFilesInTree',
      {'treeUri': treeUri},
    );
    if (result == null) return const [];
    return result.map((raw) {
      final map = Map<String, dynamic>.from(raw as Map);
      return SafTreeFileEntry(
        name: map['name'] as String? ?? '',
        uri: map['uri'] as String? ?? '',
        size: (map['size'] as num?)?.toInt() ?? 0,
        lastModified: DateTime.fromMillisecondsSinceEpoch(
          (map['lastModified'] as num?)?.toInt() ?? 0,
        ),
      );
    }).where((e) => e.name.isNotEmpty && e.uri.isNotEmpty).toList();
  }

  static Future<bool> deleteFileInTree(String fileUri) async {
    if (!isSupported) return false;
    final ok = await _channel.invokeMethod<bool>(
      'deleteFileInTree',
      {'fileUri': fileUri},
    );
    return ok ?? false;
  }

  /// Copy a SAF document URI to [targetPath] (used for pending outbox cache).
  static Future<String?> copyFileUriToTargetPath(
    String fileUri,
    String targetPath,
  ) async {
    if (!isSupported) return null;
    final result = await _channel.invokeMethod<String>(
      'copyFileUriToPath',
      {
        'fileUri': fileUri,
        'targetPath': targetPath,
      },
    );
    return result;
  }

  /// Copy a SAF document URI into app temp cache for preview / clipboard.
  static Future<String?> copyFileToCache(
    String fileUri,
    String displayName,
  ) async {
    if (!isSupported) return null;
    final tempDir = await path_provider.getTemporaryDirectory();
    final safeName = displayName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final targetPath = p.join(
      tempDir.path,
      'save_folder_preview_${DateTime.now().microsecondsSinceEpoch}_$safeName',
    );
    return copyFileUriToTargetPath(fileUri, targetPath);
  }
}

class SafCopyResult {
  final String displayName;
  final String? uri;

  const SafCopyResult({required this.displayName, this.uri});
}

class SafTreeFileEntry {
  final String name;
  final String uri;
  final int size;
  final DateTime lastModified;

  const SafTreeFileEntry({
    required this.name,
    required this.uri,
    required this.size,
    required this.lastModified,
  });
}
