import { logger } from '../logger';

const TAG = 's3LocalTest';
const DEFAULT_TIMEOUT_MS = 15_000;

/** User-Agent for direct S3 presigned requests (some providers e.g. CSTCloud Data Capsule validate UA). */
export const S3_COMPATIBLE_USER_AGENT = 'ShrimpSend/1.0 S3Compat';

export function sanitizePresignedUrlForLog(url: string): string {
  try {
    const u = new URL(url);
    u.search = '';
    return u.toString();
  } catch {
    return url.split('?')[0] ?? url;
  }
}

export function presignQueryParam(url: string, key: string): string | null {
  try {
    return new URL(url).searchParams.get(key);
  } catch {
    return null;
  }
}

export function logPresignedUrlSummary(url: string, bucket?: string): void {
  const sanitized = sanitizePresignedUrlForLog(url);
  const signedHeaders = presignQueryParam(url, 'X-Amz-SignedHeaders');
  const credential = presignQueryParam(url, 'X-Amz-Credential');
  let credentialScope: string | null = credential;
  if (credential?.includes('/')) {
    credentialScope = credential.split('/').slice(1).join('/');
  }
  let pathStyleLikely: boolean | null = null;
  if (bucket) {
    try {
      pathStyleLikely = new URL(url).pathname.includes(`/${bucket}`);
    } catch {
      pathStyleLikely = null;
    }
  }
  let host = '';
  try {
    host = new URL(url).host;
  } catch {
    host = '';
  }
  logger.info(
    TAG,
    'presigned url host=',
    host,
    'pathStyleLikely=',
    pathStyleLikely,
    'signedHeaders=',
    signedHeaders,
    'credentialScope=',
    credentialScope,
    'sanitized=',
    sanitized,
  );
}

/**
 * Probe S3 reachability from the client network using a server-issued presigned URL.
 */
export async function headPresignedUrl(
  url: string,
  timeoutMs = DEFAULT_TIMEOUT_MS,
  userAgent?: string,
): Promise<void> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  const ua = userAgent?.trim() || S3_COMPATIBLE_USER_AGENT;
  try {
    const res = await fetch(url, {
      method: 'HEAD',
      signal: controller.signal,
      headers: { 'User-Agent': ua },
    });
    if (res.status >= 200 && res.status < 300) return;

    const sanitized = sanitizePresignedUrlForLog(url);
    let bodySnippet = '';
    try {
      const text = await res.text();
      bodySnippet = text.length > 500 ? text.slice(0, 500) : text;
    } catch {
      bodySnippet = '';
    }
    logger.warn(
      TAG,
      'HEAD failed status=',
      res.status,
      'url=',
      sanitized,
      'x-amz-error-code=',
      res.headers.get('x-amz-error-code'),
      'x-amz-error-message=',
      res.headers.get('x-amz-error-message'),
      'content-type=',
      res.headers.get('content-type'),
      'body=',
      bodySnippet,
    );
    throw new Error(`S3 HEAD failed (HTTP ${res.status})`);
  } catch (e) {
    if (e instanceof DOMException && e.name === 'AbortError') {
      throw new Error('S3 connection timed out');
    }
    throw e;
  } finally {
    clearTimeout(timer);
  }
}

/** Remove legacy localStorage entry that stored AK/SK before client-side cache removal. */
export function clearLegacyS3ConfigCache(): void {
  try {
    localStorage.removeItem('s3_config_local');
  } catch {
    // ignore
  }
}
