export type DocsRegion = 'mainland' | 'overseas';
export type DocsLocale = 'zh' | 'en';
export type DocsDocId = 'intro' | 's3' | 'privacy' | 'terms' | 'contact';

export type S3SectionId =
  | 'overview'
  | 'bitiful'
  | 'built-in'
  | 'tencent-cos'
  | 'cloudflare-r2'
  | 'rustfs';

export type DocsHeading = {
  depth: 2 | 3;
  title: string;
  id: string;
};

export type DocsMarkdownSource = {
  id: DocsDocId;
  section?: S3SectionId;
  source: string;
  headings: DocsHeading[];
};

export type ResolvedDocsSlug =
  | { kind: 'doc'; doc: Exclude<DocsDocId, 's3'> }
  | { kind: 's3'; section: S3SectionId }
  | { kind: 's3-redirect' };

export const MAINLAND_S3_SECTION_IDS: S3SectionId[] = [
  'overview',
  'bitiful',
  'tencent-cos',
  'cloudflare-r2',
  'rustfs',
];

export const OVERSEAS_S3_SECTION_IDS: S3SectionId[] = [
  'overview',
  'built-in',
  'cloudflare-r2',
  'rustfs',
];

/** Union of all S3 section ids (for slug validation and nav key maps). */
export const S3_SECTION_IDS: S3SectionId[] = [
  'overview',
  'bitiful',
  'built-in',
  'tencent-cos',
  'cloudflare-r2',
  'rustfs',
];

const OVERSEAS_ONLY_S3_SECTIONS = new Set<S3SectionId>(['built-in']);
const MAINLAND_ONLY_S3_SECTIONS = new Set<S3SectionId>(['bitiful', 'tencent-cos']);

export function isS3SectionId(value: string): value is S3SectionId {
  return S3_SECTION_IDS.includes(value as S3SectionId);
}

export function s3SectionsForRegion(region: DocsRegion): S3SectionId[] {
  return region === 'overseas' ? OVERSEAS_S3_SECTION_IDS : MAINLAND_S3_SECTION_IDS;
}

export function resolveDocsSlug(slug: string[], region: DocsRegion): ResolvedDocsSlug {
  if (slug.length === 0) {
    throw new Error('Empty docs slug');
  }
  const [first, second] = slug;
  if (first === 's3') {
    if (!second) return { kind: 's3-redirect' };
    if (!isS3SectionId(second)) throw new Error(`Unknown S3 section: ${second}`);
    if (OVERSEAS_ONLY_S3_SECTIONS.has(second) && region !== 'overseas') {
      throw new Error(`S3 section unavailable in region: ${second}`);
    }
    if (MAINLAND_ONLY_S3_SECTIONS.has(second) && region === 'overseas') {
      throw new Error(`S3 section unavailable in region: ${second}`);
    }
    return { kind: 's3', section: second };
  }
  if (slug.length !== 1) {
    throw new Error(`Invalid docs slug: ${slug.join('/')}`);
  }
  if (first === 'intro' || first === 'privacy' || first === 'terms' || first === 'contact') {
    return { kind: 'doc', doc: first };
  }
  throw new Error(`Unknown docs slug: ${slug.join('/')}`);
}

export function slugifyHeading(input: string): string {
  const base = input
    .replace(/[`*_~[\]()]/g, '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^\p{Letter}\p{Number}-]+/gu, '');
  return base || 'section';
}

export function allDocsSlugs(region: DocsRegion): string[][] {
  const topLevel: string[][] = (['intro', 'privacy', 'terms', 'contact'] as const).map((doc) => [doc]);
  const s3Slugs: string[][] = [
    ['s3'],
    ...s3SectionsForRegion(region).map((section) => ['s3', section]),
  ];
  return [...topLevel, ...s3Slugs];
}
