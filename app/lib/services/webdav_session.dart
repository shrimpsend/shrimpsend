import 'dart:typed_data';

import 'package:webdav_client/webdav_client.dart' as wd;

import '../api/webdav.dart';
import '../logger.dart';
import 'webdav_credential_store.dart';

final logWebDav = logSettings;

class WebDavEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final int? size;
  final DateTime? lastModified;

  const WebDavEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.lastModified,
  });
}

/// Thin adapter over vendored [wd.Client] for Ultrasend WebDAV UI.
class WebDavClient {
  WebDavClient(WebDavCredentials creds) : _client = _createClient(creds);

  final wd.Client _client;

  static wd.Client _createClient(WebDavCredentials creds) {
    final client = wd.newClient(
      buildWebDavRootUri(creds.baseUrl, creds.rootPath),
      user: creds.username,
      password: creds.password,
    );
    client.setConnectTimeout(15000);
    client.setSendTimeout(60000);
    client.setReceiveTimeout(60000);
    return client;
  }

  Future<void> ping() => _guard(() => _client.ping());

  Future<List<WebDavEntry>> listDirectory(String relativePath) async {
    return _guard(() async {
      final listPath = appRelativeToWebDavListPath(relativePath);
      final files = await _client.readDir(listPath);
      return files.map((f) => _toEntry(f)).toList();
    });
  }

  Future<void> downloadFile(String relativePath, String localFilePath) async {
    return _guard(() async {
      await _client.read2File(
        appRelativeToWebDavResourcePath(relativePath),
        localFilePath,
      );
    });
  }

  Future<void> uploadFile(String relativePath, List<int> bytes) async {
    return _guard(() async {
      await _client.write(
        appRelativeToWebDavResourcePath(relativePath),
        Uint8List.fromList(bytes),
      );
    });
  }

  Future<void> createDirectory(String relativePath) async {
    return _guard(() async {
      await _client.mkdirAll(
        appRelativeToWebDavResourcePath(relativePath, isDirectory: true),
      );
    });
  }

  Future<void> deleteResource(String relativePath, {bool isDirectory = false}) async {
    return _guard(() async {
      await _client.remove(
        appRelativeToWebDavResourcePath(relativePath, isDirectory: isDirectory),
      );
    });
  }

  Future<void> moveResource(
    String fromPath,
    String toPath, {
    bool isDirectory = false,
  }) async {
    return _guard(() async {
      await _client.rename(
        appRelativeToWebDavResourcePath(fromPath, isDirectory: isDirectory),
        appRelativeToWebDavResourcePath(toPath, isDirectory: isDirectory),
        true,
      );
    });
  }

  WebDavEntry _toEntry(wd.File file) {
    final path = webDavPathToAppRelative(file.path);
    final name = (file.name != null && file.name!.isNotEmpty)
        ? file.name!
        : _nameFromPath(path);
    return WebDavEntry(
      name: name,
      path: path,
      isDirectory: file.isDir ?? false,
      size: file.size,
      lastModified: file.mTime,
    );
  }

  String _nameFromPath(String appRelative) {
    if (appRelative.isEmpty) return '/';
    final parts = appRelative.split('/');
    return parts.last;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      final status = _extractHttpStatus(e);
      logWebDav.warning(
        'webdav request failed status=$status message=${redactWebDavSecrets('$e')}',
      );
      if (status != null) {
        throw Exception('WebDAV 操作失败 (HTTP $status)');
      }
      throw Exception('WebDAV 操作失败');
    }
  }
}

int? _extractHttpStatus(Object error) {
  try {
    final response = (error as dynamic).response;
    if (response == null) return null;
    return response.statusCode as int?;
  } catch (_) {
    return null;
  }
}

/// Merge [baseUrl] and [rootPath] into client root URI (trailing `/`).
String buildWebDavRootUri(String baseUrl, String rootPath) {
  var base = baseUrl.trim();
  if (!base.startsWith('http://') && !base.startsWith('https://')) {
    throw ArgumentError('baseUrl must start with http:// or https://');
  }
  while (base.endsWith('/') && base.length > 'https://x'.length) {
    base = base.substring(0, base.length - 1);
  }

  var root = rootPath.trim();
  if (root.isEmpty || root == '/') {
    return '$base/';
  }
  if (!root.startsWith('/')) {
    root = '/$root';
  }
  while (root.endsWith('/') && root.length > 1) {
    root = root.substring(0, root.length - 1);
  }
  return '$base$root/';
}

/// App `''` / `Documents/foo` → WebDAV list path `/` or `/Documents/foo/`.
String appRelativeToWebDavListPath(String relativePath) {
  final rel = relativePath.trim();
  if (rel.isEmpty) return '/';
  var path = rel.startsWith('/') ? rel : '/$rel';
  if (!path.endsWith('/')) path = '$path/';
  return path;
}

/// App relative path → WebDAV resource path for GET/PUT/DELETE/MOVE.
String appRelativeToWebDavResourcePath(
  String relativePath, {
  bool isDirectory = false,
}) {
  final rel = relativePath.trim();
  if (rel.isEmpty) return '/';
  var path = rel.startsWith('/') ? rel : '/$rel';
  if (isDirectory && !path.endsWith('/')) {
    path = '$path/';
  }
  return path;
}

/// WebDAV `/Documents/foo/` → app `Documents/foo`.
String webDavPathToAppRelative(String? webDavPath) {
  if (webDavPath == null || webDavPath.isEmpty || webDavPath == '/') {
    return '';
  }
  var path = webDavPath;
  if (path.startsWith('/')) {
    path = path.substring(1);
  }
  if (path.endsWith('/') && path.length > 1) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}
