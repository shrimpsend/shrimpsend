export type S3ObjectUrlParams = {
  endpoint: string;
  bucket: string;
  key: string;
  pathStyleAccessEnabled?: boolean;
};

export type S3BucketUrlParams = {
  endpoint: string;
  bucket: string;
  pathStyleAccessEnabled?: boolean;
};

function normalizeEndpoint(endpoint: string): string {
  return endpoint.replace(/\/$/, '');
}

function encodeObjectPath(bucket: string, key: string, pathStyleAccessEnabled: boolean): string {
  const segments = pathStyleAccessEnabled ? [bucket, ...key.split('/')] : key.split('/');
  return '/' + segments.map((s) => encodeURIComponent(s)).join('/');
}

/**
 * Build the object URL used for SigV4 signing and direct S3 requests.
 * Path-style: {endpoint}/{bucket}/{key}
 * Virtual-hosted: {scheme}://{bucket}.{host}/{key}
 */
export function buildS3ObjectUrl(params: S3ObjectUrlParams): URL {
  const pathStyle = params.pathStyleAccessEnabled !== false;
  const base = normalizeEndpoint(params.endpoint);
  const encodedPath = encodeObjectPath(params.bucket, params.key, pathStyle);

  if (pathStyle) {
    return new URL(`${base}${encodedPath}`);
  }

  const endpointUrl = new URL(base.includes('://') ? base : `https://${base}`);
  const bucketPrefix = `${params.bucket}.`;
  if (!endpointUrl.hostname.startsWith(bucketPrefix)) {
    endpointUrl.hostname = bucketPrefix + endpointUrl.hostname;
  }
  endpointUrl.pathname = encodedPath;
  endpointUrl.search = '';
  endpointUrl.hash = '';
  return endpointUrl;
}
