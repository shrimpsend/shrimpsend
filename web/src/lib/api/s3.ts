import { logger } from '../logger';
import { getApiUrl, TAG, AuthError, getToken, isAuthFailure, withAuthRetry } from './client';
import { clearLegacyS3ConfigCache, headPresignedUrl } from '../services/s3LocalTest';

export type S3ConfigRequest = {
  endpoint: string;
  region?: string;
  bucket: string;
  accessKeyId: string;
  /** 留空则保存时不修改已有 secret */
  secretAccessKey?: string;
  /** true = path-style; false = virtual-hosted. Defaults to true when omitted. */
  pathStyleAccessEnabled?: boolean;
};

/**
 * 当前用户的 S3 存储模式。
 * - `DISABLED`：当前部署没有内置 S3，且该用户也未配置自建 S3。
 * - `HOSTED`：该用户走平台内置 S3（仅海外集群且 hosted 桶启用时可见）。
 * - `CUSTOM`：该用户已经配置了自建 S3。
 */
export type S3StorageMode = 'DISABLED' | 'HOSTED' | 'CUSTOM';

export type S3ConfigResponse = {
  /** Convenience flag, equivalent to `mode != 'DISABLED'`. */
  configured: boolean;
  mode: S3StorageMode;
  /** 当前部署是否提供了内置 S3（决定是否展示「切换回内置 S3」按钮）。 */
  hostedAvailable: boolean;
  /**
   * 用户后端是否保存过自建 S3 凭证。HOSTED 模式下若为 true，表示曾经配置过、
   * 当前主动选择走内置 S3，可一键「使用已保存的自建 S3」切回，无需重新输入。
   */
  customSaved: boolean;
  /** 当前部署下 S3 配置说明文档绝对 URL（Flutter 外开）。 */
  documentationUrl?: string;
  endpoint?: string;
  region?: string;
  bucket?: string;
  accessKeyId?: string;
  pathStyleAccessEnabled?: boolean;
};

function disabledResponse(): S3ConfigResponse {
  return { configured: false, mode: 'DISABLED', hostedAvailable: false, customSaved: false };
}

function normalizeS3Response(raw: unknown): S3ConfigResponse {
  const obj = (raw ?? {}) as Record<string, unknown>;
  const fallbackConfigured = obj.configured === true;
  const rawMode = typeof obj.mode === 'string' ? obj.mode.toUpperCase() : null;
  const mode: S3StorageMode =
    rawMode === 'CUSTOM' || rawMode === 'HOSTED' || rawMode === 'DISABLED'
      ? (rawMode as S3StorageMode)
      : fallbackConfigured
        ? 'CUSTOM'
        : 'DISABLED';
  // 兼容旧后端：CUSTOM 模式必然意味着已保存
  const customSaved = obj.customSaved === true || mode === 'CUSTOM';
  return {
    configured: mode !== 'DISABLED',
    mode,
    hostedAvailable: obj.hostedAvailable === true,
    customSaved,
    documentationUrl: typeof obj.documentationUrl === 'string' ? obj.documentationUrl : undefined,
    endpoint: typeof obj.endpoint === 'string' ? obj.endpoint : undefined,
    region: typeof obj.region === 'string' ? obj.region : undefined,
    bucket: typeof obj.bucket === 'string' ? obj.bucket : undefined,
    accessKeyId: typeof obj.accessKeyId === 'string' ? obj.accessKeyId : undefined,
    pathStyleAccessEnabled:
      typeof obj.pathStyleAccessEnabled === 'boolean' ? obj.pathStyleAccessEnabled : undefined,
  };
}

export async function getS3Config(): Promise<S3ConfigResponse> {
  clearLegacyS3ConfigCache();
  if (!getToken()) {
    logger.debug(TAG, 'getS3Config: no token');
    return disabledResponse();
  }
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) return disabledResponse();
    const res = await fetch(`${getApiUrl()}/api/s3/config`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) return disabledResponse();
    const data = normalizeS3Response(await res.json());
    logger.info(TAG, 'getS3Config mode=', data.mode, 'hostedAvailable=', data.hostedAvailable);
    return data;
  });
}

export async function hasS3Config(): Promise<boolean> {
  const data = await getS3Config();
  return data.configured;
}

export async function saveS3Config(data: S3ConfigRequest): Promise<void> {
  logger.info(TAG, 'saveS3Config endpoint=', data.endpoint, 'bucket=', data.bucket);
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const res = await fetch(`${getApiUrl()}/api/s3/config`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify(data),
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      logger.warn(TAG, 'saveS3Config failed', res.status);
      throw new Error('Failed to save S3 config');
    }
    logger.info(TAG, 'saveS3Config success');
  });
}

export async function clearS3Config(): Promise<void> {
  logger.info(TAG, 'clearS3Config');
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const res = await fetch(`${getApiUrl()}/api/s3/config`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      logger.warn(TAG, 'clearS3Config failed', res.status);
      throw new Error('Failed to clear S3 config');
    }
    logger.info(TAG, 'clearS3Config success');
  });
}

/** 切换到平台内置 S3，但保留已保存的自建 S3 凭证。 */
export async function switchToHostedS3(): Promise<void> {
  logger.info(TAG, 'switchToHostedS3');
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const res = await fetch(`${getApiUrl()}/api/s3/use-hosted`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: '{}',
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      logger.warn(TAG, 'switchToHostedS3 failed', res.status);
      throw new Error('Failed to switch to hosted S3');
    }
    logger.info(TAG, 'switchToHostedS3 success');
  });
}

/** 切换到此前保存的自建 S3 配置（要求后端已存在 BYO 凭证）。 */
export async function switchToCustomS3(): Promise<void> {
  logger.info(TAG, 'switchToCustomS3');
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const res = await fetch(`${getApiUrl()}/api/s3/use-custom`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: '{}',
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      logger.warn(TAG, 'switchToCustomS3 failed', res.status);
      throw new Error('Failed to switch to custom S3');
    }
    logger.info(TAG, 'switchToCustomS3 success');
  });
}

async function fetchS3TestUrl(): Promise<string> {
  const token = getToken();
  if (!token) throw new Error('errors.notAuthenticated');
  const res = await fetch(`${getApiUrl()}/api/s3/test`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: '{}',
  });
  if (isAuthFailure(res)) throw new AuthError();
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    const msg = (err as { error?: string }).error || 'errors.s3TestFailed';
    throw new Error(msg);
  }
  const data = (await res.json()) as { url?: string };
  if (!data.url) throw new Error('errors.s3TestFailed');
  return data.url;
}

/** CUSTOM：服务端签发 HeadBucket 预签名 URL，本机 HEAD 探测。HOSTED：无需测试。 */
export async function testS3Config(): Promise<void> {
  logger.info(TAG, 'testS3Config');
  const cfg = await getS3Config();
  if (cfg.mode === 'HOSTED') return;
  if (cfg.mode !== 'CUSTOM') throw new Error('errors.s3TestFailed');

  return withAuthRetry(async () => {
    const url = await fetchS3TestUrl();
    await headPresignedUrl(url);
    logger.info(TAG, 'testS3Config success');
  });
}

/** 用于在线状态：HOSTED 已配置即在线；CUSTOM 需本机 HEAD 通过。 */
export async function checkS3Online(): Promise<boolean> {
  const cfg = await getS3Config();
  if (!cfg.configured) return false;
  if (cfg.mode === 'HOSTED') return true;
  if (cfg.mode !== 'CUSTOM') return false;
  try {
    await testS3Config();
    return true;
  } catch {
    return false;
  }
}

export type PresignUploadResponse = { uploadUrl: string; key: string };

export async function presignUpload(fileName: string, contentType?: string, contentLength?: number): Promise<PresignUploadResponse> {
  logger.info(TAG, 'presignUpload fileName=', fileName);
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const body: Record<string, unknown> = { fileName, contentType };
    if (contentLength != null && contentLength > 0) body.contentLength = contentLength;
    const res = await fetch(`${getApiUrl()}/api/s3/presign-upload`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify(body),
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      logger.warn(TAG, 'presignUpload failed', res.status);
      throw new Error('Failed to get upload URL');
    }
    const data = await res.json() as PresignUploadResponse;
    logger.info(TAG, 'presignUpload success key=', data.key);
    return data;
  });
}

export async function getDownloadUrl(key: string): Promise<string> {
  logger.info(TAG, 'getDownloadUrl key=', key);
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const res = await fetch(`${getApiUrl()}/api/s3/download-url?key=${encodeURIComponent(key)}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      logger.warn(TAG, 'getDownloadUrl failed', res.status);
      throw new Error('Failed to get download URL');
    }
    const data = (await res.json()) as { url: string };
    return data.url;
  });
}

// ── Multipart Upload ───────────────────────────────────────────────

export type MultipartInitiateResponse = { uploadId: string; key: string };

export async function initiateMultipartUpload(
  fileName: string,
  contentType?: string,
  totalSize?: number,
): Promise<MultipartInitiateResponse> {
  logger.info(TAG, 'initiateMultipart fileName=', fileName);
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const body: Record<string, unknown> = { fileName, contentType };
    if (totalSize != null && totalSize > 0) body.totalSize = totalSize;
    const res = await fetch(`${getApiUrl()}/api/s3/multipart/initiate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify(body),
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) throw new Error('Failed to initiate multipart upload');
    return (await res.json()) as MultipartInitiateResponse;
  });
}

export async function presignUploadPart(
  uploadId: string,
  key: string,
  partNumber: number,
): Promise<string> {
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const res = await fetch(`${getApiUrl()}/api/s3/multipart/presign-part`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify({ uploadId, key, partNumber }),
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) throw new Error('Failed to presign part');
    const data = (await res.json()) as { url: string };
    return data.url;
  });
}

export async function completeMultipartUpload(
  uploadId: string,
  key: string,
  parts: Array<{ partNumber: number; eTag: string }>,
): Promise<void> {
  logger.info(TAG, 'completeMultipart key=', key, 'parts=', parts.length);
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const res = await fetch(`${getApiUrl()}/api/s3/multipart/complete`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify({ uploadId, key, parts }),
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) throw new Error('Failed to complete multipart upload');
  });
}

export async function abortMultipartUpload(
  uploadId: string,
  key: string,
): Promise<void> {
  logger.info(TAG, 'abortMultipart key=', key);
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const res = await fetch(`${getApiUrl()}/api/s3/multipart/abort`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify({ uploadId, key }),
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) throw new Error('Failed to abort multipart upload');
  });
}
