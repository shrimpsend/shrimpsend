import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/webdav.dart';

const _storageKeyPrefix = 'webdav_cred_';

/// Session cache for WebDAV credentials. Never use SharedPreferences/sqflite.
class WebDavCredentialStore {
  WebDavCredentialStore._();
  static final WebDavCredentialStore instance = WebDavCredentialStore._();

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  final Map<int, WebDavCredentials> _memory = {};

  WebDavCredentials? getFromMemory(int connectionId) => _memory[connectionId];

  Future<WebDavCredentials?> read(int connectionId) async {
    final cached = _memory[connectionId];
    if (cached != null) return cached;
    final raw = await _secure.read(key: '$_storageKeyPrefix$connectionId');
    if (raw == null || raw.isEmpty) return null;
    try {
      final creds = WebDavCredentials.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      _memory[connectionId] = creds;
      return creds;
    } catch (_) {
      await _secure.delete(key: '$_storageKeyPrefix$connectionId');
      return null;
    }
  }

  Future<void> write(int connectionId, WebDavCredentials creds) async {
    _memory[connectionId] = creds;
    await _secure.write(
      key: '$_storageKeyPrefix$connectionId',
      value: jsonEncode(creds.toJson()),
    );
  }

  Future<void> remove(int connectionId) async {
    _memory.remove(connectionId);
    await _secure.delete(key: '$_storageKeyPrefix$connectionId');
  }

  Future<void> wipeAll() async {
    _memory.clear();
    await _secure.deleteAll();
  }
}

String redactWebDavSecrets(String message) {
  var out = message;
  out = out.replaceAll(
    RegExp(r'://[^:@/]+:[^@/]+@'),
    '://***:***@',
  );
  return out;
}
