import 'dart:convert';
import 'package:http/http.dart' as http;
import '../logger.dart';
import '../services/s3_local_test.dart';
import 'client.dart';

enum S3StorageMode {
  /// 当前部署没有内置 S3，且该用户也未配置自建 S3。
  disabled,

  /// 该用户走平台内置 S3（仅海外集群且 hosted 桶启用时可见）。
  hosted,

  /// 该用户已经配置了自建 S3。
  custom;

  static S3StorageMode parse(dynamic raw, {required bool fallbackConfigured}) {
    if (raw is String) {
      switch (raw.toUpperCase()) {
        case 'CUSTOM':
          return S3StorageMode.custom;
        case 'HOSTED':
          return S3StorageMode.hosted;
        case 'DISABLED':
          return S3StorageMode.disabled;
      }
    }
    return fallbackConfigured ? S3StorageMode.custom : S3StorageMode.disabled;
  }
}

class S3ConfigDetail {
  final bool configured;
  final S3StorageMode mode;
  final bool hostedAvailable;
  final bool customSaved;
  final String? endpoint;
  final String? region;
  final String? bucket;
  final String? accessKeyId;
  final bool? pathStyleAccessEnabled;
  final String? documentationUrl;

  S3ConfigDetail({
    required this.configured,
    required this.mode,
    required this.hostedAvailable,
    this.customSaved = false,
    this.endpoint,
    this.region,
    this.bucket,
    this.accessKeyId,
    this.pathStyleAccessEnabled,
    this.documentationUrl,
  });

  factory S3ConfigDetail.fromJson(Map<String, dynamic> j) {
    final fallbackConfigured = (j['configured'] as bool?) ?? false;
    final mode = S3StorageMode.parse(
      j['mode'],
      fallbackConfigured: fallbackConfigured,
    );
    final customSaved = (j['customSaved'] as bool?) ?? (mode == S3StorageMode.custom);
    return S3ConfigDetail(
      configured: mode != S3StorageMode.disabled,
      mode: mode,
      hostedAvailable: (j['hostedAvailable'] as bool?) ?? false,
      customSaved: customSaved,
      endpoint: j['endpoint'] as String?,
      region: j['region'] as String?,
      bucket: j['bucket'] as String?,
      accessKeyId: j['accessKeyId'] as String?,
      pathStyleAccessEnabled: j['pathStyleAccessEnabled'] as bool?,
      documentationUrl: j['documentationUrl'] as String?,
    );
  }

  factory S3ConfigDetail.disabled() => S3ConfigDetail(
    configured: false,
    mode: S3StorageMode.disabled,
    hostedAvailable: false,
  );
}

Future<S3ConfigDetail> getS3Config() async {
  await clearLegacyS3ConfigCache();
  if (!hasAccessToken) {
    logApi.fine('getS3Config no token');
    return S3ConfigDetail.disabled();
  }
  return withAuthRetry(() async {
    final r = await http.get(
      Uri.parse('$apiBaseUrl/api/s3/config'),
      headers: apiHeaders,
    );
    if (r.statusCode == 401) throw AuthException();
    if (r.statusCode != 200) return S3ConfigDetail.disabled();
    final detail = S3ConfigDetail.fromJson(
      jsonDecode(r.body) as Map<String, dynamic>,
    );
    logApi.info(
      'getS3Config mode=${detail.mode.name} hostedAvailable=${detail.hostedAvailable}',
    );
    return detail;
  });
}

Future<bool> hasS3Config() async {
  final detail = await getS3Config();
  return detail.configured;
}

class S3ConfigRequest {
  final String endpoint;
  final String? region;
  final String bucket;
  final String accessKeyId;
  final String secretAccessKey;
  final bool pathStyleAccessEnabled;

  S3ConfigRequest({
    required this.endpoint,
    this.region,
    required this.bucket,
    required this.accessKeyId,
    required this.secretAccessKey,
    this.pathStyleAccessEnabled = true,
  });

  Map<String, dynamic> toJson() => {
    'endpoint': endpoint,
    if (region != null && region!.isNotEmpty) 'region': region,
    'bucket': bucket,
    'accessKeyId': accessKeyId,
    if (secretAccessKey.isNotEmpty) 'secretAccessKey': secretAccessKey,
    'pathStyleAccessEnabled': pathStyleAccessEnabled,
  };
}

Future<void> saveS3Config(S3ConfigRequest req) async {
  logApi.info('saveS3Config endpoint=${req.endpoint} bucket=${req.bucket}');
  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/s3/config'),
      headers: apiHeaders,
      body: jsonEncode(req.toJson()),
    );
    checkAuthResponse(r, fallback: '保存 S3 配置失败');
    if (r.statusCode != 204) throw Exception('保存失败');
    logApi.info('saveS3Config success');
  });
}

Future<void> testS3Config() async {
  logApi.info('testS3Config');
  final detail = await getS3Config();
  if (detail.mode == S3StorageMode.hosted) return;
  if (detail.mode != S3StorageMode.custom) {
    throw Exception('S3 连接测试失败');
  }

  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/s3/test'),
      headers: apiHeaders,
      body: '{}',
    );
    checkAuthResponse(r, fallback: 'S3 连接测试失败');
    if (r.statusCode != 200) {
      try {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        final err = body['error'] as String?;
        if (err != null && err.isNotEmpty) throw Exception(err);
      } catch (e) {
        if (e is Exception) rethrow;
      }
      throw Exception('S3 连接测试失败');
    }
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final url = data['url'] as String?;
    if (url == null || url.isEmpty) throw Exception('S3 连接测试失败');
    await headPresignedUrl(url);
    logApi.info('testS3Config success');
  });
}

Future<bool> checkS3Online() async {
  final detail = await getS3Config();
  if (!detail.configured) return false;
  if (detail.mode == S3StorageMode.hosted) return true;
  if (detail.mode != S3StorageMode.custom) return false;
  try {
    await testS3Config();
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> clearS3Config() async {
  logApi.info('clearS3Config');
  return withAuthRetry(() async {
    final r = await http.delete(
      Uri.parse('$apiBaseUrl/api/s3/config'),
      headers: apiHeaders,
    );
    checkAuthResponse(r, fallback: '清空 S3 配置失败');
    logApi.info('clearS3Config success');
  });
}

Future<void> useHostedS3() async {
  logApi.info('useHostedS3');
  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/s3/use-hosted'),
      headers: apiHeaders,
      body: '{}',
    );
    checkAuthResponse(r, fallback: '切换到内置 S3 失败');
    logApi.info('useHostedS3 success');
  });
}

Future<void> useCustomS3() async {
  logApi.info('useCustomS3');
  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/s3/use-custom'),
      headers: apiHeaders,
      body: '{}',
    );
    checkAuthResponse(r, fallback: '切换到自建 S3 失败');
    logApi.info('useCustomS3 success');
  });
}

class PresignUploadResponse {
  final String uploadUrl;
  final String key;

  PresignUploadResponse({required this.uploadUrl, required this.key});

  factory PresignUploadResponse.fromJson(Map<String, dynamic> j) =>
      PresignUploadResponse(
        uploadUrl: j['uploadUrl'] as String,
        key: j['key'] as String,
      );
}

Future<PresignUploadResponse> presignUpload(
  String fileName, {
  String? contentType,
  int? contentLength,
}) async {
  logApi.info('presignUpload fileName=$fileName');
  return withAuthRetry(() async {
    final body = <String, dynamic>{'fileName': fileName};
    if (contentType != null && contentType.isNotEmpty) {
      body['contentType'] = contentType;
    }
    if (contentLength != null && contentLength > 0) {
      body['contentLength'] = contentLength;
    }
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/s3/presign-upload'),
      headers: apiHeaders,
      body: jsonEncode(body),
    );
    checkAuthResponse(r, fallback: '获取上传地址失败');
    final res = PresignUploadResponse.fromJson(
      jsonDecode(r.body) as Map<String, dynamic>,
    );
    logApi.info('presignUpload success key=${res.key}');
    return res;
  });
}

Future<String> getDownloadUrl(String key) async {
  logApi.info('getDownloadUrl key=$key');
  return withAuthRetry(() async {
    final r = await http.get(
      Uri.parse('$apiBaseUrl/api/s3/download-url').replace(
        queryParameters: {'key': key},
      ),
      headers: apiHeaders,
    );
    checkAuthResponse(r, fallback: '获取下载地址失败');
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return data['url'] as String;
  });
}

class MultipartInitiateResponse {
  final String uploadId;
  final String key;

  MultipartInitiateResponse({required this.uploadId, required this.key});

  factory MultipartInitiateResponse.fromJson(Map<String, dynamic> j) =>
      MultipartInitiateResponse(
        uploadId: j['uploadId'] as String,
        key: j['key'] as String,
      );
}

Future<MultipartInitiateResponse> initiateMultipartUpload(
  String fileName, {
  String? contentType,
  int? totalSize,
}) async {
  logApi.info('initiateMultipart fileName=$fileName');
  return withAuthRetry(() async {
    final body = <String, dynamic>{'fileName': fileName};
    if (contentType != null && contentType.isNotEmpty) {
      body['contentType'] = contentType;
    }
    if (totalSize != null && totalSize > 0) body['totalSize'] = totalSize;
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/s3/multipart/initiate'),
      headers: apiHeaders,
      body: jsonEncode(body),
    );
    checkAuthResponse(r, fallback: '创建分片上传失败');
    return MultipartInitiateResponse.fromJson(
      jsonDecode(r.body) as Map<String, dynamic>,
    );
  });
}

Future<String> presignUploadPart({
  required String uploadId,
  required String key,
  required int partNumber,
}) async {
  logApi.fine('presignPart part=$partNumber');
  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/s3/multipart/presign-part'),
      headers: apiHeaders,
      body: jsonEncode({
        'uploadId': uploadId,
        'key': key,
        'partNumber': partNumber,
      }),
    );
    checkAuthResponse(r, fallback: '获取分片上传地址失败');
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return data['url'] as String;
  });
}

Future<void> completeMultipartUpload({
  required String uploadId,
  required String key,
  required List<Map<String, dynamic>> parts,
}) async {
  logApi.info('completeMultipart key=$key parts=${parts.length}');
  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/s3/multipart/complete'),
      headers: apiHeaders,
      body: jsonEncode({'uploadId': uploadId, 'key': key, 'parts': parts}),
    );
    checkAuthResponse(r, fallback: '完成分片上传失败');
  });
}

Future<void> abortMultipartUpload({
  required String uploadId,
  required String key,
}) async {
  logApi.info('abortMultipart key=$key');
  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/s3/multipart/abort'),
      headers: apiHeaders,
      body: jsonEncode({'uploadId': uploadId, 'key': key}),
    );
    checkAuthResponse(r, fallback: '取消分片上传失败');
  });
}
