import '../api/webdav.dart';

/// Zotero 8+ UA for CSTCloud Data Capsule WebDAV (matches backend).
const kCstCloudWebDavUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0 Zotero/8.0.3';

bool isCstCloudWebDav(String baseUrl) {
  final trimmed = baseUrl.trim();
  if (trimmed.isEmpty) return false;
  try {
    return Uri.parse(trimmed).host.toLowerCase().endsWith('cstcloud.cn');
  } catch (_) {
    return false;
  }
}

String? resolveWebDavUserAgent(WebDavCredentials creds) {
  final fromApi = creds.userAgent?.trim();
  if (fromApi != null && fromApi.isNotEmpty) return fromApi;
  if (isCstCloudWebDav(creds.baseUrl)) return kCstCloudWebDavUserAgent;
  return null;
}

bool cstCloudNeedsCredentialRefresh(WebDavCredentials creds) {
  if (!isCstCloudWebDav(creds.baseUrl)) return false;
  final ua = creds.userAgent?.trim();
  return ua == null || ua.isEmpty;
}

/// User-facing message when a write/upload is attempted on CSTCloud WebDAV.
const kCstCloudWebDavUploadBlockedMessage =
    '数据胶囊 WebDAV 不支持上传，仅可浏览和下载已有文件';

/// CSTCloud WebDAV only accepts Zotero sync writes (`.prop` / `.zip` under `zotero/`).
bool cstCloudWebDavBlocksGeneralUpload(String baseUrl) =>
    isCstCloudWebDav(baseUrl);
