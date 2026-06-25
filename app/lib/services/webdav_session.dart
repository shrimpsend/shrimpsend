import 'dart:io' as io;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:webdav_client/webdav_client.dart' as wd;

import '../api/webdav.dart';
import '../logger.dart';
import 'webdav_credential_store.dart';
import 'webdav_cstcloud.dart';

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
    final userAgent = resolveWebDavUserAgent(creds);
    if (userAgent != null && userAgent.isNotEmpty) {
      client.c.configureUserAgent(userAgent);
    }
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

  Future<void> downloadFile(
    String relativePath,
    String localFilePath, {
    void Function(int count, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    return _guard(() async {
      await _client.read2File(
        appRelativeToWebDavResourcePath(relativePath),
        localFilePath,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    });
  }

  Future<void> uploadFile(
    String relativePath,
    List<int> bytes, {
    void Function(int count, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    return _guard(() async {
      await _client.write(
        appRelativeToWebDavResourcePath(relativePath),
        Uint8List.fromList(bytes),
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    });
  }

  Future<void> uploadFileFromPath(
    String relativePath,
    String localFilePath, {
    void Function(int count, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    return _guard(() async {
      await _client.writeFromFile(
        localFilePath,
        appRelativeToWebDavResourcePath(relativePath),
        onProgress: onProgress,
        cancelToken: cancelToken,
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

  Future<void> copyResource(
    String fromPath,
    String toPath, {
    bool isDirectory = false,
  }) async {
    return _guard(() async {
      await _client.copy(
        appRelativeToWebDavResourcePath(fromPath, isDirectory: isDirectory),
        appRelativeToWebDavResourcePath(toPath, isDirectory: isDirectory),
        true,
      );
    });
  }

  Future<int?> fileSize(String relativePath) async {
    return _guard(() async {
      final file = await _client.readProps(
        appRelativeToWebDavResourcePath(relativePath),
      );
      return file.size;
    });
  }

  /// Returns local file size when [localPath] exists.
  static int localFileSize(String localPath) {
    try {
      return io.File(localPath).lengthSync();
    } catch (_) {
      return 0;
    }
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

  /// Probe PUT to root / zotero paths for upload permission diagnosis.
  Future<List<String>> diagnoseUpload() async {
    const probeBody = 'ultrasend-probe';
    const probes = <({String target, String path})>[
      (target: 'root', path: '/__ultrasend_probe.txt'),
      (target: 'zotero_dir', path: '/zotero/__ultrasend_probe.txt'),
      (target: 'zotero_prop', path: '/zotero/UTPROBE0.prop'),
    ];

    final results = <String>[];

    try {
      await _client.c.wdMkcol(_client, '/zotero/');
    } catch (_) {
      // zotero/ may already exist or MKCOL may be denied; probes still run.
    }

    for (final probe in probes) {
      try {
        final resp = await _client.c.req(
          _client,
          'PUT',
          probe.path,
          data: Uint8List.fromList(probeBody.codeUnits),
          optionsHandler: (options) {
            options.headers ??= {};
            options.headers!['content-length'] = probeBody.length;
            options.headers!['content-type'] = 'text/plain';
          },
        );
        final status = resp.statusCode ?? 0;
        final body = _truncateResponseBody(resp.data);
        final url = redactWebDavSecrets(resp.requestOptions.uri.toString());
        final line =
            '${probe.target} path=${probe.path} status=$status url=$url body=$body';
        results.add(line);
        logWebDav.info('webdav upload probe $line');

        if (status == 200 || status == 201 || status == 204) {
          try {
            await _client.c.wdDelete(_client, probe.path);
          } catch (_) {}
        }
      } catch (e) {
        final status = _extractHttpStatus(e);
        final detail = _formatWebDavErrorDetail(e, status);
        final line =
            '${probe.target} path=${probe.path} error status=$status$detail';
        results.add(line);
        logWebDav.info('webdav upload probe $line');
      }
    }

    return results;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      final status = _extractHttpStatus(e);
      final detail = _formatWebDavErrorDetail(e, status);
      logWebDav.warning(
        'webdav request failed status=$status$detail message=${redactWebDavSecrets('$e')}',
      );
      if (status != null) {
        final body = _responseBodyFromError(e);
        if (status == 403 &&
            body.toLowerCase().contains('client type mismatch')) {
          throw Exception('WebDAV 操作失败：$kCstCloudWebDavUploadBlockedMessage');
        }
        throw Exception('WebDAV 操作失败 (HTTP $status)');
      }
      throw Exception('WebDAV 操作失败');
    }
  }
}

String _responseBodyFromError(Object error) {
  try {
    return _truncateResponseBody((error as dynamic).response?.data);
  } catch (_) {
    return '';
  }
}

String _truncateResponseBody(dynamic data, {int maxLen = 300}) {
  if (data == null) return '';
  String text;
  if (data is List<int>) {
    text = String.fromCharCodes(data);
  } else if (data is Uint8List) {
    text = String.fromCharCodes(data);
  } else {
    text = data.toString();
  }
  text = redactWebDavSecrets(text.trim());
  if (text.isEmpty) return '';
  if (text.length > maxLen) {
    return '${text.substring(0, maxLen)}...';
  }
  return text;
}

String _formatWebDavErrorDetail(Object error, int? status) {
  if (status == null) return '';
  try {
    final dio = error as dynamic;
    final method = dio.requestOptions?.method as String?;
    final statusMessage = dio.response?.statusMessage as String?;
    final uri = dio.requestOptions?.uri?.toString();
    final parts = <String>[];
    if (method != null && method.isNotEmpty) parts.add(' method=$method');
    if (uri != null && uri.isNotEmpty) {
      parts.add(' url=${redactWebDavSecrets(uri)}');
    }
    if (statusMessage != null && statusMessage.isNotEmpty) {
      parts.add(' reason=$statusMessage');
    }
    if (status == 403) {
      final body = _truncateResponseBody(dio.response?.data);
      if (body.toLowerCase().contains('client type mismatch')) {
        parts.add(' hint=cstcloud_zotero_sync_only');
      } else {
        parts.add(' hint=check_auth_and_user_agent');
      }
      if (body.isNotEmpty) parts.add(' body=$body');
    }
    return parts.join();
  } catch (_) {
    return status == 403 ? ' hint=check_auth_and_user_agent' : '';
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
