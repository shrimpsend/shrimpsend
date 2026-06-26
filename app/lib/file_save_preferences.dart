import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

const _keySaveToGallery = 'ultrasend_save_to_gallery';
const _keyDeleteCacheAfterSave = 'ultrasend_delete_cache_after_save';
const _keyCustomSaveDir = 'ultrasend_custom_save_dir';
const _keyCustomSaveTreeUri = 'ultrasend_custom_save_tree_uri';
const _keyCustomSaveTreeDisplayName = 'ultrasend_custom_save_tree_display_name';

Future<bool> getSaveToGallery() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_keySaveToGallery) ?? false;
}

Future<void> setSaveToGallery(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_keySaveToGallery, value);
}

Future<bool> getDeleteCacheAfterSave() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_keyDeleteCacheAfterSave) ?? true;
}

Future<void> setDeleteCacheAfterSave(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_keyDeleteCacheAfterSave, value);
}

/// Desktop / POSIX custom receive root (non-Android SAF).
Future<String?> getCustomSaveDir() async {
  if (Platform.isAndroid) return null;
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString(_keyCustomSaveDir);
  if (value == null || value.trim().isEmpty) return null;
  return normalizeCustomSaveDirValue(value);
}

Future<void> setCustomSaveDir(String? value) async {
  if (Platform.isAndroid) return;
  final prefs = await SharedPreferences.getInstance();
  if (value == null || value.trim().isEmpty) {
    await prefs.remove(_keyCustomSaveDir);
    return;
  }
  await prefs.setString(_keyCustomSaveDir, normalizeCustomSaveDirValue(value));
}

Future<void> clearCustomSaveDir() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_keyCustomSaveDir);
  await prefs.remove(_keyCustomSaveTreeUri);
  await prefs.remove(_keyCustomSaveTreeDisplayName);
}

/// Android SAF document-tree URI for mirroring received files.
Future<String?> getCustomSaveTreeUri() async {
  if (!Platform.isAndroid) return null;
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString(_keyCustomSaveTreeUri);
  if (value == null || value.trim().isEmpty) return null;
  return value.trim();
}

Future<String?> getCustomSaveTreeDisplayName() async {
  if (!Platform.isAndroid) return null;
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString(_keyCustomSaveTreeDisplayName);
  if (value == null || value.trim().isEmpty) return null;
  return value.trim();
}

Future<void> setCustomSaveTreeUri({
  required String treeUri,
  required String displayName,
}) async {
  if (!Platform.isAndroid) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyCustomSaveTreeUri, treeUri.trim());
  await prefs.setString(_keyCustomSaveTreeDisplayName, displayName.trim());
  await prefs.remove(_keyCustomSaveDir);
}

String normalizeCustomSaveDirValue(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('content://')) return trimmed;
  return p.normalize(Directory(trimmed).absolute.path);
}

const _keyReceiveDirFallbackIntended = 'ultrasend_receive_dir_fallback_intended';
const _keyReceiveDirFallbackReason = 'ultrasend_receive_dir_fallback_reason';
const _keyReceiveDirFallbackCurrent = 'ultrasend_receive_dir_fallback_current';
const _keyReceiveDirFallbackAt = 'ultrasend_receive_dir_fallback_at';

class ReceiveDirFallbackInfo {
  final String intendedPath;
  final String fallbackReason;
  final String currentPath;
  final DateTime? recordedAt;

  const ReceiveDirFallbackInfo({
    required this.intendedPath,
    required this.fallbackReason,
    required this.currentPath,
    this.recordedAt,
  });

  bool get isEmpty =>
      intendedPath.trim().isEmpty && fallbackReason.trim().isEmpty;
}

Future<ReceiveDirFallbackInfo?> getReceiveDirFallback() async {
  final prefs = await SharedPreferences.getInstance();
  final intended = prefs.getString(_keyReceiveDirFallbackIntended);
  if (intended == null || intended.trim().isEmpty) return null;
  final reason = prefs.getString(_keyReceiveDirFallbackReason) ?? '';
  final current = prefs.getString(_keyReceiveDirFallbackCurrent) ?? '';
  final atMs = prefs.getInt(_keyReceiveDirFallbackAt);
  return ReceiveDirFallbackInfo(
    intendedPath: intended,
    fallbackReason: reason,
    currentPath: current,
    recordedAt: atMs != null
        ? DateTime.fromMillisecondsSinceEpoch(atMs)
        : null,
  );
}

Future<void> setReceiveDirFallback({
  required String intendedPath,
  required String fallbackReason,
  required String currentPath,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyReceiveDirFallbackIntended, intendedPath);
  await prefs.setString(_keyReceiveDirFallbackReason, fallbackReason);
  await prefs.setString(_keyReceiveDirFallbackCurrent, currentPath);
  await prefs.setInt(
    _keyReceiveDirFallbackAt,
    DateTime.now().millisecondsSinceEpoch,
  );
}

Future<void> clearReceiveDirFallback() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_keyReceiveDirFallbackIntended);
  await prefs.remove(_keyReceiveDirFallbackReason);
  await prefs.remove(_keyReceiveDirFallbackCurrent);
  await prefs.remove(_keyReceiveDirFallbackAt);
}
