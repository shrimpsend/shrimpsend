/// CSTCloud Data Capsule client-app bindings (must match AccessKey creation in console).
class S3ClientAppOption {
  final String id;
  final String label;

  const S3ClientAppOption({required this.id, required this.label});
}

const s3ClientAppOptions = [
  S3ClientAppOption(id: 's3drive', label: 'S3Drive'),
  S3ClientAppOption(id: 's3browser', label: 'S3Browser'),
  S3ClientAppOption(id: 'rclone', label: 'Rclone'),
  S3ClientAppOption(id: 'obsidian', label: 'Obsidian'),
  S3ClientAppOption(id: 'cherry_studio', label: 'Cherry Studio'),
];

bool s3EndpointRequiresClientApp(String endpoint) {
  return endpoint.toLowerCase().contains('cstcloud.cn');
}
