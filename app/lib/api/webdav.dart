import 'dart:convert';

import 'package:http/http.dart' as http;

import '../logger.dart';
import 'client.dart';

class WebDavConnectionSummary {
  final int id;
  final String name;
  final String baseUrl;
  final String rootPath;
  final String? clientApp;
  final DateTime? updatedAt;

  const WebDavConnectionSummary({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.rootPath,
    this.clientApp,
    this.updatedAt,
  });

  factory WebDavConnectionSummary.fromJson(Map<String, dynamic> j) {
    return WebDavConnectionSummary(
      id: (j['id'] as num).toInt(),
      name: j['name'] as String? ?? '',
      baseUrl: j['baseUrl'] as String? ?? '',
      rootPath: j['rootPath'] as String? ?? '/',
      clientApp: j['clientApp'] as String?,
      updatedAt: j['updatedAt'] != null
          ? DateTime.tryParse(j['updatedAt'].toString())
          : null,
    );
  }
}

class WebDavCredentials {
  final String username;
  final String password;
  final String baseUrl;
  final String rootPath;
  final String? clientApp;
  final String? userAgent;

  const WebDavCredentials({
    required this.username,
    required this.password,
    required this.baseUrl,
    required this.rootPath,
    this.clientApp,
    this.userAgent,
  });

  factory WebDavCredentials.fromJson(Map<String, dynamic> j) {
    return WebDavCredentials(
      username: j['username'] as String? ?? '',
      password: j['password'] as String? ?? '',
      baseUrl: j['baseUrl'] as String? ?? '',
      rootPath: j['rootPath'] as String? ?? '/',
      clientApp: j['clientApp'] as String?,
      userAgent: j['userAgent'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
    'baseUrl': baseUrl,
    'rootPath': rootPath,
    if (clientApp != null) 'clientApp': clientApp,
    if (userAgent != null) 'userAgent': userAgent,
  };
}

class WebDavTestResult {
  final bool ok;
  final String message;

  const WebDavTestResult({required this.ok, required this.message});

  factory WebDavTestResult.fromJson(Map<String, dynamic> j) {
    return WebDavTestResult(
      ok: j['ok'] as bool? ?? false,
      message: j['message'] as String? ?? '',
    );
  }
}

class WebDavConnectionRequest {
  final String name;
  final String baseUrl;
  final String? username;
  final String? password;
  final String? rootPath;
  final String? clientApp;

  const WebDavConnectionRequest({
    required this.name,
    required this.baseUrl,
    this.username,
    this.password,
    this.rootPath,
    this.clientApp,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'baseUrl': baseUrl,
    if (username != null && username!.isNotEmpty) 'username': username,
    if (password != null && password!.isNotEmpty) 'password': password,
    if (rootPath != null) 'rootPath': rootPath,
    if (clientApp != null && clientApp!.isNotEmpty) 'clientApp': clientApp,
  };
}

Future<List<WebDavConnectionSummary>> listWebDavConnections() async {
  if (!hasAccessToken) return [];
  return withAuthRetry(() async {
    final r = await http.get(
      Uri.parse('$apiBaseUrl/api/webdav/connections'),
      headers: apiHeaders,
    );
    checkAuthResponse(r, fallback: '加载 WebDAV 连接失败');
    if (r.statusCode != 200) throw Exception('加载 WebDAV 连接失败');
    final list = jsonDecode(r.body) as List<dynamic>;
    return list
        .map((e) => WebDavConnectionSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  });
}

Future<WebDavConnectionSummary> getWebDavConnectionMeta(int id) async {
  return withAuthRetry(() async {
    final r = await http.get(
      Uri.parse('$apiBaseUrl/api/webdav/connections/$id'),
      headers: apiHeaders,
    );
    checkAuthResponse(r, fallback: '加载 WebDAV 连接失败');
    if (r.statusCode != 200) throw Exception('连接不存在');
    return WebDavConnectionSummary.fromJson(
      jsonDecode(r.body) as Map<String, dynamic>,
    );
  });
}

Future<WebDavCredentials> fetchWebDavCredentials(int id) async {
  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/webdav/connections/$id/credentials'),
      headers: apiHeaders,
    );
    checkAuthResponse(r, fallback: '获取 WebDAV 凭证失败');
    if (r.statusCode != 200) throw Exception('获取 WebDAV 凭证失败');
    return WebDavCredentials.fromJson(
      jsonDecode(r.body) as Map<String, dynamic>,
    );
  });
}

Future<WebDavConnectionSummary> createWebDavConnection(
  WebDavConnectionRequest req,
) async {
  logApi.info('createWebDavConnection name=${req.name}');
  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/webdav/connections'),
      headers: apiHeaders,
      body: jsonEncode(req.toJson()),
    );
    checkAuthResponse(r, fallback: '保存 WebDAV 连接失败');
    if (r.statusCode != 200) throw Exception('保存 WebDAV 连接失败');
    return WebDavConnectionSummary.fromJson(
      jsonDecode(r.body) as Map<String, dynamic>,
    );
  });
}

Future<WebDavConnectionSummary> updateWebDavConnection(
  int id,
  WebDavConnectionRequest req,
) async {
  logApi.info('updateWebDavConnection id=$id');
  return withAuthRetry(() async {
    final r = await http.put(
      Uri.parse('$apiBaseUrl/api/webdav/connections/$id'),
      headers: apiHeaders,
      body: jsonEncode(req.toJson()),
    );
    checkAuthResponse(r, fallback: '更新 WebDAV 连接失败');
    if (r.statusCode != 200) throw Exception('更新 WebDAV 连接失败');
    return WebDavConnectionSummary.fromJson(
      jsonDecode(r.body) as Map<String, dynamic>,
    );
  });
}

Future<void> deleteWebDavConnection(int id) async {
  return withAuthRetry(() async {
    final r = await http.delete(
      Uri.parse('$apiBaseUrl/api/webdav/connections/$id'),
      headers: apiHeaders,
    );
    checkAuthResponse(r, fallback: '删除 WebDAV 连接失败');
    if (r.statusCode != 204) throw Exception('删除 WebDAV 连接失败');
  });
}

Future<WebDavTestResult> testWebDavConnection(int id) async {
  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/webdav/connections/$id/test'),
      headers: apiHeaders,
    );
    checkAuthResponse(r, fallback: '测试 WebDAV 连接失败');
    if (r.statusCode != 200) throw Exception('测试 WebDAV 连接失败');
    return WebDavTestResult.fromJson(
      jsonDecode(r.body) as Map<String, dynamic>,
    );
  });
}

Future<WebDavTestResult> testWebDavConnectionDraft(
  WebDavConnectionRequest req,
) async {
  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/webdav/connections/test'),
      headers: apiHeaders,
      body: jsonEncode(req.toJson()),
    );
    checkAuthResponse(r, fallback: '测试 WebDAV 连接失败');
    if (r.statusCode != 200) throw Exception('测试 WebDAV 连接失败');
    return WebDavTestResult.fromJson(
      jsonDecode(r.body) as Map<String, dynamic>,
    );
  });
}
