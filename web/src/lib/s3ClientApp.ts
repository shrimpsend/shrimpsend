export const S3_CLIENT_APP_OPTIONS = [
  { id: 's3drive', label: 'S3Drive' },
  { id: 's3browser', label: 'S3Browser' },
  { id: 'rclone', label: 'Rclone' },
  { id: 'obsidian', label: 'Obsidian' },
  { id: 'cherry_studio', label: 'Cherry Studio' },
] as const;

export type S3ClientAppId = (typeof S3_CLIENT_APP_OPTIONS)[number]['id'];

export function s3EndpointRequiresClientApp(endpoint: string): boolean {
  return endpoint.toLowerCase().includes('cstcloud.cn');
}

export const S3_DEFAULT_USER_AGENT = 'ShrimpSend/1.0 S3Compat';
