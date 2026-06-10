const DEFAULT_TIMEOUT_MS = 15_000;

/**
 * Probe S3 reachability from the client network using a server-issued presigned URL.
 */
export async function headPresignedUrl(url: string, timeoutMs = DEFAULT_TIMEOUT_MS): Promise<void> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { method: 'HEAD', signal: controller.signal });
    if (res.status >= 200 && res.status < 300) return;
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
