export type S3ProviderDefaults = {
  endpoint?: string;
  region?: string;
  pathStyleAccessEnabled?: boolean;
  endpointPlaceholder?: string;
  regionPlaceholder?: string;
};

export type S3ProviderFields = {
  endpoint?: string;
  region?: string;
  pathStyle?: string;
  clientApp?: string;
  tencentRegionPicker?: boolean;
};

export type S3ProviderCatalogItem = {
  id: string;
  label: string;
  labelZh?: string;
  docsSection: string;
  defaults: S3ProviderDefaults;
  fields: S3ProviderFields;
};

export type S3ClientAppOption = {
  id: string;
  label: string;
};

export type S3TencentCosRegion = {
  id: string;
  label: string;
  region: string;
  endpoint: string;
};

export type S3ProvidersCatalog = {
  providers: S3ProviderCatalogItem[];
  clientAppOptions: S3ClientAppOption[];
  tencentCosRegions: S3TencentCosRegion[];
};

export const S3_PROVIDER_CUSTOM = 'custom';
export const S3_PROVIDER_DATA_CAPSULE = 'data_capsule';
export const S3_PROVIDER_BITIFUL = 'bitiful';
export const S3_PROVIDER_TENCENT_COS = 'tencent_cos';
export const S3_PROVIDER_CLOUDFLARE_R2 = 'cloudflare_r2';

export const DEFAULT_S3_REGION = 'us-east-1';

export function inferProviderIdFromEndpoint(endpoint: string): string {
  const lower = endpoint.toLowerCase();
  if (lower.includes('cstcloud.cn')) return S3_PROVIDER_DATA_CAPSULE;
  if (lower.includes('bitiful.net')) return S3_PROVIDER_BITIFUL;
  if (lower.includes('myqcloud.com') || lower.includes('.cos.')) {
    return S3_PROVIDER_TENCENT_COS;
  }
  if (lower.includes('r2.cloudflarestorage.com')) return S3_PROVIDER_CLOUDFLARE_R2;
  return S3_PROVIDER_CUSTOM;
}

export function providerDisplayLabel(
  provider: S3ProviderCatalogItem,
  localeTag: string,
): string {
  if (localeTag.startsWith('zh') && provider.labelZh) return provider.labelZh;
  return provider.label;
}

export function findProvider(
  catalog: S3ProvidersCatalog | null,
  providerId: string | undefined,
): S3ProviderCatalogItem | undefined {
  if (!catalog || !providerId) return undefined;
  return catalog.providers.find((p) => p.id === providerId);
}

export function providerRequiresClientApp(
  catalog: S3ProvidersCatalog | null,
  providerId: string,
): boolean {
  return findProvider(catalog, providerId)?.fields.clientApp === 'required';
}

export function applyProviderDefaults(
  provider: S3ProviderCatalogItem,
  tencentCosRegions: S3TencentCosRegion[],
): {
  endpoint?: string;
  region?: string;
  pathStyleAccessEnabled?: boolean;
  tencentCosRegionId?: string;
} {
  const d = provider.defaults;
  const out: {
    endpoint?: string;
    region?: string;
    pathStyleAccessEnabled?: boolean;
    tencentCosRegionId?: string;
  } = {};
  if (provider.fields.tencentRegionPicker && tencentCosRegions.length > 0) {
    const first = tencentCosRegions[0];
    out.endpoint = first.endpoint;
    out.region = first.region;
    out.tencentCosRegionId = first.id;
  } else {
    if (d.endpoint) out.endpoint = d.endpoint;
    if (d.region != null) out.region = d.region;
  }
  if (d.pathStyleAccessEnabled != null) {
    out.pathStyleAccessEnabled = d.pathStyleAccessEnabled;
  }
  return out;
}

export function matchTencentCosRegionId(
  regions: S3TencentCosRegion[],
  endpoint: string,
  region: string,
): string | undefined {
  const byBoth = regions.find((r) => r.endpoint === endpoint && r.region === region);
  if (byBoth) return byBoth.id;
  const byRegion = regions.find((r) => r.region === region);
  return byRegion?.id;
}

export function buildProviderDocsUrl(
  documentationUrl: string | undefined,
  docsSection: string,
  localePath: 'zh' | 'en',
): string | undefined {
  if (!docsSection || docsSection === 'overview') {
    return documentationUrl;
  }
  return `/${localePath}/docs/s3/${docsSection}`;
}
