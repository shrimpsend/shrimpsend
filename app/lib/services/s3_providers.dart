import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api/client.dart';
import '../logger.dart';

const s3ProviderCustom = 'custom';
const s3ProviderDataCapsule = 'data_capsule';
const s3ProviderBitiful = 'bitiful';
const s3ProviderTencentCos = 'tencent_cos';
const s3ProviderCloudflareR2 = 'cloudflare_r2';

class S3ProviderDefaults {
  final String? endpoint;
  final String? region;
  final bool? pathStyleAccessEnabled;
  final String? endpointPlaceholder;
  final String? regionPlaceholder;

  const S3ProviderDefaults({
    this.endpoint,
    this.region,
    this.pathStyleAccessEnabled,
    this.endpointPlaceholder,
    this.regionPlaceholder,
  });

  factory S3ProviderDefaults.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const S3ProviderDefaults();
    return S3ProviderDefaults(
      endpoint: j['endpoint'] as String?,
      region: j['region'] as String?,
      pathStyleAccessEnabled: j['pathStyleAccessEnabled'] as bool?,
      endpointPlaceholder: j['endpointPlaceholder'] as String?,
      regionPlaceholder: j['regionPlaceholder'] as String?,
    );
  }
}

class S3ProviderFields {
  final String endpoint;
  final String region;
  final String pathStyle;
  final String clientApp;
  final bool tencentRegionPicker;

  const S3ProviderFields({
    this.endpoint = 'editable',
    this.region = 'editable',
    this.pathStyle = 'editable',
    this.clientApp = 'hidden',
    this.tencentRegionPicker = false,
  });

  factory S3ProviderFields.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const S3ProviderFields();
    return S3ProviderFields(
      endpoint: j['endpoint'] as String? ?? 'editable',
      region: j['region'] as String? ?? 'editable',
      pathStyle: j['pathStyle'] as String? ?? 'editable',
      clientApp: j['clientApp'] as String? ?? 'hidden',
      tencentRegionPicker: j['tencentRegionPicker'] as bool? ?? false,
    );
  }

  bool get requiresClientApp => clientApp == 'required';
  bool get endpointFixed => endpoint == 'fixed';
  bool get regionReadonly => region == 'readonly' || region == 'fixed';
  bool get pathStyleFixed => pathStyle == 'fixed';
}

class S3ProviderCatalogItem {
  final String id;
  final String label;
  final String? labelZh;
  final String docsSection;
  final S3ProviderDefaults defaults;
  final S3ProviderFields fields;

  const S3ProviderCatalogItem({
    required this.id,
    required this.label,
    this.labelZh,
    required this.docsSection,
    required this.defaults,
    required this.fields,
  });

  factory S3ProviderCatalogItem.fromJson(Map<String, dynamic> j) {
    return S3ProviderCatalogItem(
      id: j['id'] as String,
      label: j['label'] as String? ?? j['id'] as String,
      labelZh: j['labelZh'] as String?,
      docsSection: j['docsSection'] as String? ?? 'overview',
      defaults: S3ProviderDefaults.fromJson(
        j['defaults'] as Map<String, dynamic>?,
      ),
      fields: S3ProviderFields.fromJson(j['fields'] as Map<String, dynamic>?),
    );
  }

  String displayLabel(String localeName) {
    if (localeName.startsWith('zh') && labelZh != null && labelZh!.isNotEmpty) {
      return labelZh!;
    }
    return label;
  }
}

class S3ClientAppOption {
  final String id;
  final String label;

  const S3ClientAppOption({required this.id, required this.label});

  factory S3ClientAppOption.fromJson(Map<String, dynamic> j) {
    return S3ClientAppOption(
      id: j['id'] as String,
      label: j['label'] as String? ?? j['id'] as String,
    );
  }
}

class S3TencentCosRegion {
  final String id;
  final String label;
  final String region;
  final String endpoint;

  const S3TencentCosRegion({
    required this.id,
    required this.label,
    required this.region,
    required this.endpoint,
  });

  factory S3TencentCosRegion.fromJson(Map<String, dynamic> j) {
    return S3TencentCosRegion(
      id: j['id'] as String,
      label: j['label'] as String? ?? j['id'] as String,
      region: j['region'] as String,
      endpoint: j['endpoint'] as String,
    );
  }
}

class S3ProvidersCatalog {
  final List<S3ProviderCatalogItem> providers;
  final List<S3ClientAppOption> clientAppOptions;
  final List<S3TencentCosRegion> tencentCosRegions;

  const S3ProvidersCatalog({
    required this.providers,
    required this.clientAppOptions,
    required this.tencentCosRegions,
  });

  factory S3ProvidersCatalog.fromJson(Map<String, dynamic> j) {
    return S3ProvidersCatalog(
      providers: (j['providers'] as List<dynamic>? ?? [])
          .map((e) => S3ProviderCatalogItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      clientAppOptions: (j['clientAppOptions'] as List<dynamic>? ?? [])
          .map((e) => S3ClientAppOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      tencentCosRegions: (j['tencentCosRegions'] as List<dynamic>? ?? [])
          .map((e) => S3TencentCosRegion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  S3ProviderCatalogItem? findProvider(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final p in providers) {
      if (p.id == id) return p;
    }
    return null;
  }
}

Future<S3ProvidersCatalog> fetchS3Providers() async {
  if (!hasAccessToken) {
    return S3ProvidersCatalog(
      providers: const [],
      clientAppOptions: const [],
      tencentCosRegions: const [],
    );
  }
  return withAuthRetry(() async {
    final r = await http.get(
      Uri.parse('$apiBaseUrl/api/s3/providers'),
      headers: apiHeaders,
    );
    if (r.statusCode == 401) throw AuthException();
    if (r.statusCode != 200) {
      logApi.warning('fetchS3Providers failed status=${r.statusCode}');
      return S3ProvidersCatalog(
        providers: const [],
        clientAppOptions: const [],
        tencentCosRegions: const [],
      );
    }
    return S3ProvidersCatalog.fromJson(
      jsonDecode(r.body) as Map<String, dynamic>,
    );
  });
}

String inferProviderIdFromEndpoint(String endpoint) {
  final lower = endpoint.toLowerCase();
  if (lower.contains('cstcloud.cn')) return s3ProviderDataCapsule;
  if (lower.contains('bitiful.net')) return s3ProviderBitiful;
  if (lower.contains('myqcloud.com') || lower.contains('.cos.')) {
    return s3ProviderTencentCos;
  }
  if (lower.contains('r2.cloudflarestorage.com')) return s3ProviderCloudflareR2;
  return s3ProviderCustom;
}

void applyProviderDefaults({
  required S3ProviderCatalogItem provider,
  required void Function(String endpoint) setEndpoint,
  required void Function(String region) setRegion,
  required void Function(bool pathStyle) setPathStyle,
  List<S3TencentCosRegion>? tencentCosRegions,
  void Function(String? tencentRegionId)? setTencentRegionId,
}) {
  final d = provider.defaults;
  if (d.endpoint != null && d.endpoint!.isNotEmpty) {
    setEndpoint(d.endpoint!);
  }
  if (provider.fields.tencentRegionPicker &&
      tencentCosRegions != null &&
      tencentCosRegions.isNotEmpty) {
    final first = tencentCosRegions.first;
    setEndpoint(first.endpoint);
    setRegion(first.region);
    setTencentRegionId?.call(first.id);
  } else if (d.region != null) {
    setRegion(d.region!);
  }
  if (d.pathStyleAccessEnabled != null) {
    setPathStyle(d.pathStyleAccessEnabled!);
  }
}

String? buildProviderDocsUrl(String? documentationUrl, String docsSection) {
  if (documentationUrl == null || documentationUrl.isEmpty) return null;
  if (docsSection.isEmpty || docsSection == 'overview') return documentationUrl;
  final base = documentationUrl.trim();
  if (base.endsWith('/overview')) {
    return '${base.substring(0, base.length - '/overview'.length)}/$docsSection';
  }
  if (base.endsWith('/')) {
    return '$base$docsSection';
  }
  return '$base/$docsSection';
}

String? matchTencentCosRegionId(
  List<S3TencentCosRegion> regions,
  String endpoint,
  String region,
) {
  for (final r in regions) {
    if (r.endpoint == endpoint && r.region == region) return r.id;
  }
  for (final r in regions) {
    if (r.region == region) return r.id;
  }
  return null;
}
