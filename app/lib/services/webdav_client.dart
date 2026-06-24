import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../api/webdav.dart';
import '../logger.dart';
import 'webdav_credential_store.dart';

final logWebDav = logSettings; // reuse settings channel for webdav ops

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

class WebDavClient {
  WebDavClient(this._creds);

  final WebDavCredentials _creds;

  Map<String, String> get _authHeaders {
    final token = base64Encode(
      utf8.encode('${_creds.username}:${_creds.password}'),
    );
    return {'Authorization': 'Basic $token'};
  }

  String get rootPath => _normalizeRoot(_creds.rootPath);

  Future<List<WebDavEntry>> listDirectory(String relativePath) async {
    final url = _buildUrl(relativePath, trailingSlash: true);
    final body = '''
<?xml version="1.0" encoding="utf-8" ?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:displayname/>
    <d:getcontentlength/>
    <d:getlastmodified/>
    <d:resourcetype/>
  </d:prop>
</d:propfind>
''';
    final request = http.Request('PROPFIND', Uri.parse(url))
      ..headers.addAll(_authHeaders)
      ..headers['Depth'] = '1'
      ..headers['Content-Type'] = 'application/xml; charset=utf-8'
      ..body = body;

    final streamed = await request.send();
    final r = await http.Response.fromStream(streamed);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      logWebDav.warning(
        'PROPFIND failed status=${r.statusCode} url=${redactWebDavSecrets(url)}',
      );
      throw Exception('无法列出目录 (HTTP ${r.statusCode})');
    }
    return _parsePropfind(r.body, relativePath);
  }

  Future<void> downloadFile(String relativePath, String localFilePath) async {
    final url = _buildUrl(relativePath, trailingSlash: false);
    final request = http.Request('GET', Uri.parse(url))
      ..headers.addAll(_authHeaders);
    final streamed = await request.send();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('下载失败 (HTTP ${streamed.statusCode})');
    }
    final file = File(localFilePath);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    await streamed.stream.pipe(sink);
    await sink.close();
  }

  Future<void> uploadFile(String relativePath, List<int> bytes) async {
    final url = _buildUrl(relativePath, trailingSlash: false);
    final r = await http.put(
      Uri.parse(url),
      headers: {..._authHeaders, 'Content-Type': 'application/octet-stream'},
      body: bytes,
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('上传失败 (HTTP ${r.statusCode})');
    }
  }

  Future<void> createDirectory(String relativePath) async {
    final url = _buildUrl(relativePath, trailingSlash: true);
    final request = http.Request('MKCOL', Uri.parse(url))
      ..headers.addAll(_authHeaders);
    final streamed = await request.send();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('创建文件夹失败 (HTTP ${streamed.statusCode})');
    }
  }

  Future<void> deleteResource(String relativePath) async {
    final url = _buildUrl(relativePath, trailingSlash: false);
    final r = await http.delete(Uri.parse(url), headers: _authHeaders);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('删除失败 (HTTP ${r.statusCode})');
    }
  }

  Future<void> moveResource(String fromPath, String toPath) async {
    final fromUrl = _buildUrl(fromPath, trailingSlash: false);
    final toUrl = _buildUrl(toPath, trailingSlash: false);
    final request = http.Request('MOVE', Uri.parse(fromUrl))
      ..headers.addAll(_authHeaders)
      ..headers['Destination'] = toUrl
      ..headers['Overwrite'] = 'T';
    final streamed = await request.send();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('移动失败 (HTTP ${streamed.statusCode})');
    }
  }

  String _buildUrl(String relativePath, {required bool trailingSlash}) {
    final base = _creds.baseUrl.trim();
    final normalizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final root = rootPath == '/' ? '' : rootPath;
    var rel = relativePath.trim();
    if (rel.startsWith('/')) rel = rel.substring(1);
    final segments = <String>[];
    if (root.isNotEmpty) segments.add(root.replaceAll(RegExp(r'^/|/$'), ''));
    if (rel.isNotEmpty) segments.add(rel.replaceAll(RegExp(r'^/|/$'), ''));
    var path = segments.join('/');
    if (path.isNotEmpty) {
      path = '/$path';
      if (trailingSlash) path = '$path/';
    } else if (trailingSlash) {
      path = '/';
    }
    return '$normalizedBase$path';
  }

  static String _normalizeRoot(String rootPath) {
    var p = rootPath.trim();
    if (p.isEmpty) return '/';
    if (!p.startsWith('/')) p = '/$p';
    while (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  List<WebDavEntry> _parsePropfind(String xmlBody, String currentRelative) {
    final doc = XmlDocument.parse(xmlBody);
    final responses = doc.findAllElements('response', namespace: '*');
    final currentUrl = _buildUrl(currentRelative, trailingSlash: true);
    final entries = <WebDavEntry>[];

    for (final response in responses) {
      final hrefEl = response.getElement('href', namespace: '*');
      if (hrefEl == null) continue;
      final href = Uri.decodeComponent(hrefEl.innerText.trim());
      final absHref = _resolveHref(href);
      if (_sameResource(absHref, currentUrl)) continue;

      final propstat = response.getElement('propstat', namespace: '*');
      final prop = propstat?.getElement('prop', namespace: '*');
      if (prop == null) continue;

      final displayName = prop.getElement('displayname', namespace: '*')?.innerText;
      final resourceType = prop.getElement('resourcetype', namespace: '*');
      final isDir = resourceType?.getElement('collection', namespace: '*') != null;
      final sizeText = prop.getElement('getcontentlength', namespace: '*')?.innerText;
      final modifiedText = prop.getElement('getlastmodified', namespace: '*')?.innerText;

      final name = displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : p.basename(Uri.parse(absHref).path);

      final relPath = _hrefToRelative(absHref);
      if (relPath == null) continue;

      entries.add(
        WebDavEntry(
          name: name,
          path: relPath,
          isDirectory: isDir,
          size: sizeText != null ? int.tryParse(sizeText.trim()) : null,
          lastModified: modifiedText != null ? HttpDate.parse(modifiedText.trim()) : null,
        ),
      );
    }

    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  String _resolveHref(String href) {
    if (href.startsWith('http://') || href.startsWith('https://')) return href;
    final base = _creds.baseUrl.trim();
    final normalizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    if (href.startsWith('/')) return '$normalizedBase$href';
    return '$normalizedBase/$href';
  }

  bool _sameResource(String a, String b) {
    return _normalizeUrl(a) == _normalizeUrl(b);
  }

  String _normalizeUrl(String url) {
    var u = url.trim();
    if (u.endsWith('/') && u.length > 1) u = u.substring(0, u.length - 1);
    return u;
  }

  String? _hrefToRelative(String absHref) {
    final base = _normalizeUrl(_creds.baseUrl.trim());
    final normalized = _normalizeUrl(absHref);
    if (!normalized.startsWith(base)) return null;
    var suffix = normalized.substring(base.length);
    if (suffix.isEmpty) return '';
    if (!suffix.startsWith('/')) suffix = '/$suffix';
    final root = rootPath == '/' ? '' : rootPath;
    if (root.isNotEmpty && suffix.startsWith(root)) {
      suffix = suffix.substring(root.length);
    }
    if (suffix.startsWith('/')) suffix = suffix.substring(1);
    if (suffix.endsWith('/')) suffix = suffix.substring(0, suffix.length - 1);
    return suffix;
  }
}
