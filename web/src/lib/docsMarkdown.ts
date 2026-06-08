import fs from 'fs';
import path from 'path';
import {
  allDocsSlugs,
  resolveDocsSlug,
  slugifyHeading,
  type DocsDocId,
  type DocsHeading,
  type DocsLocale,
  type DocsMarkdownSource,
  type DocsRegion,
  type S3SectionId,
} from '@/lib/docsConfig';

export type {
  DocsDocId,
  DocsHeading,
  DocsLocale,
  DocsMarkdownSource,
  DocsRegion,
  ResolvedDocsSlug,
  S3SectionId,
} from '@/lib/docsConfig';

export {
  allDocsSlugs,
  isS3SectionId,
  resolveDocsSlug,
  s3SectionsForRegion,
  slugifyHeading,
  S3_SECTION_IDS,
} from '@/lib/docsConfig';

const DOC_FILE_MAP: Record<DocsRegion, Record<DocsLocale, Record<Exclude<DocsDocId, 's3'>, string[]>>> = {
  mainland: {
    zh: {
      intro: ['web', 'cn-mainland', 'intro.md'],
      privacy: ['legal', 'cn-mainland', 'privacy-policy.md'],
      terms: ['legal', 'cn-mainland', 'terms-of-service.md'],
      contact: ['web', 'cn-mainland', 'contact.md'],
    },
    en: {
      intro: ['web', 'cn-mainland', 'intro.en.md'],
      privacy: ['legal', 'cn-mainland', 'privacy-policy.en.md'],
      terms: ['legal', 'cn-mainland', 'terms-of-service.en.md'],
      contact: ['web', 'cn-mainland', 'contact.en.md'],
    },
  },
  overseas: {
    zh: {
      intro: ['web', 'intl', 'intro.zh.md'],
      privacy: ['legal', 'intl', 'privacy-policy.zh.md'],
      terms: ['legal', 'intl', 'terms-of-service.zh.md'],
      contact: ['web', 'intl', 'contact.zh.md'],
    },
    en: {
      intro: ['web', 'intl', 'intro.en.md'],
      privacy: ['legal', 'intl', 'privacy-policy.en.md'],
      terms: ['legal', 'intl', 'terms-of-service.en.md'],
      contact: ['web', 'intl', 'contact.en.md'],
    },
  },
};

function s3SectionFile(region: DocsRegion, locale: DocsLocale, section: S3SectionId): string[] {
  const base = region === 'mainland'
    ? ['web', 'cn-mainland', 's3', `${section}.md`]
    : ['web', 'intl', 's3', `${section}.${locale === 'zh' ? 'zh' : 'en'}.md`];

  if (region === 'mainland' && locale === 'en') {
    return ['web', 'cn-mainland', 's3', `${section}.en.md`];
  }
  return base;
}

function resolveDocsFile(segments: string[]): string {
  const rel = path.join(...segments);
  const candidates = [
    path.join(process.cwd(), '..', 'docs', rel),
    path.join(process.cwd(), 'docs', rel),
  ];
  for (const full of candidates) {
    if (fs.existsSync(full)) return full;
  }
  throw new Error(`Document not found: docs/${rel}`);
}

function readDocsMarkdown(...segments: string[]): string {
  return fs.readFileSync(resolveDocsFile(segments), 'utf8');
}

function extractHeadings(source: string): DocsHeading[] {
  const headings: DocsHeading[] = [];
  const used = new Map<string, number>();
  const pattern = /^(#{2,3})\s+(.+)$/gm;
  let match: RegExpExecArray | null;
  while ((match = pattern.exec(source)) !== null) {
    const depth = match[1].length as 2 | 3;
    const title = match[2].trim().replace(/\s+#+$/, '');
    const slug = slugifyHeading(title);
    const count = used.get(slug) ?? 0;
    used.set(slug, count + 1);
    headings.push({
      depth,
      title,
      id: count === 0 ? slug : `${slug}-${count + 1}`,
    });
  }
  return headings;
}

function doc(id: DocsDocId, source: string, section?: S3SectionId): DocsMarkdownSource {
  return {
    id,
    section,
    source,
    headings: extractHeadings(source),
  };
}

export function readDocsMarkdownDoc(
  region: DocsRegion,
  locale: DocsLocale,
  id: Exclude<DocsDocId, 's3'>,
): DocsMarkdownSource {
  return doc(id, readDocsMarkdown(...DOC_FILE_MAP[region][locale][id]));
}

export function readS3SectionDoc(
  region: DocsRegion,
  locale: DocsLocale,
  section: S3SectionId,
): DocsMarkdownSource {
  if (section === 'built-in' && region !== 'overseas') {
    throw new Error(`S3 section unavailable in region: ${section}`);
  }
  if ((section === 'bitiful' || section === 'tencent-cos') && region === 'overseas') {
    throw new Error(`S3 section unavailable in region: ${section}`);
  }
  return doc('s3', readDocsMarkdown(...s3SectionFile(region, locale, section)), section);
}

export function readDocsFromSlug(
  region: DocsRegion,
  locale: DocsLocale,
  slug: string[],
): DocsMarkdownSource {
  const resolved = resolveDocsSlug(slug, region);
  if (resolved.kind === 's3-redirect') {
    throw new Error('S3 redirect should be handled by route');
  }
  if (resolved.kind === 's3') {
    return readS3SectionDoc(region, locale, resolved.section);
  }
  return readDocsMarkdownDoc(region, locale, resolved.doc);
}
