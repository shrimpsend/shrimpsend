import type { Metadata } from 'next';
import { notFound, redirect } from 'next/navigation';
import { DocsReader } from '@/components/docs/docs-reader';
import {
  allDocsSlugs,
  readDocsFromSlug,
  resolveDocsSlug,
  type DocsDocId,
  type DocsRegion,
  type S3SectionId,
} from '@/lib/docsMarkdown';
import {
  isLocalePath,
  localePathToDocsLocale,
  localizedDocsHref,
  type LocalePath,
} from '@/lib/i18nRouting';
import { DEFAULT_OG_IMAGE, SITE_LOCALE, SITE_NAME, absoluteUrl, getConfiguredSiteOrigin, localizedAlternates } from '@/lib/seo';
import zhMessages from '@/messages/zh.json';
import enMessages from '@/messages/en.json';

export const dynamic = 'force-static';
export const dynamicParams = false;

const MESSAGES = {
  zh: zhMessages,
  en: enMessages,
} as const;

function docsRegionFromOrigin(origin: string): DocsRegion {
  return origin.includes('shrimpsend.com') ? 'overseas' : 'mainland';
}

function docTitle(lang: LocalePath, doc: DocsDocId, section?: S3SectionId): string {
  const nav = MESSAGES[lang].docs.nav;
  if (doc === 's3' && section) {
    const sectionKey = `s3${section.split('-').map((p) => p.charAt(0).toUpperCase() + p.slice(1)).join('')}` as keyof typeof nav;
    const sectionTitle = nav[sectionKey];
    if (typeof sectionTitle === 'string') {
      return `${nav.s3} · ${sectionTitle}`;
    }
  }
  switch (doc) {
    case 'intro':
      return nav.intro;
    case 's3':
      return nav.s3;
    case 'privacy':
      return nav.privacy;
    case 'terms':
      return nav.terms;
    case 'contact':
      return nav.contact;
  }
}

function s3SectionNavKey(section: S3SectionId): keyof typeof MESSAGES.zh.docs.nav {
  const map: Record<S3SectionId, keyof typeof MESSAGES.zh.docs.nav> = {
    overview: 's3Overview',
    bitiful: 's3Bitiful',
    'data-capsule': 's3DataCapsule',
    'built-in': 's3BuiltIn',
    'tencent-cos': 's3TencentCos',
    'cloudflare-r2': 's3CloudflareR2',
    rustfs: 's3Rustfs',
  };
  return map[section];
}

function docTitleFromSlug(lang: LocalePath, slug: string[]): string {
  const nav = MESSAGES[lang].docs.nav;
  if (slug[0] === 's3') {
    const section = slug[1] as S3SectionId | undefined;
    if (section) {
      const key = s3SectionNavKey(section);
      return `${nav.s3} · ${nav[key]}`;
    }
    return nav.s3;
  }
  const doc = slug[0] as DocsDocId;
  return docTitle(lang, doc);
}

function markdownDescription(source: string, fallback: string): string {
  const paragraph = source
    .split(/\n{2,}/)
    .filter((block) => !block.trimStart().startsWith('#'))
    .filter((block) => !/^\*\*(适用区域|Region)\*\*/.test(block.trimStart()))
    .map((block) => block.replace(/\s+/g, ' ').trim())
    .find((block) => block && !block.startsWith('|') && !block.startsWith('```') && !block.startsWith('!['));
  if (!paragraph) return fallback;
  return paragraph.length > 160 ? `${paragraph.slice(0, 157)}...` : paragraph;
}

function canonicalDocsPath(lang: LocalePath, slug: string[]): string {
  if (slug[0] === 's3' && slug.length === 1) {
    return localizedDocsHref(lang, 's3', 'overview');
  }
  if (slug.length === 1) {
    return localizedDocsHref(lang, slug[0] as DocsDocId);
  }
  return `/${lang}/docs/${slug.join('/')}`;
}

export function generateStaticParams() {
  const origin = getConfiguredSiteOrigin();
  const region = docsRegionFromOrigin(origin);
  return ['zh', 'en'].flatMap((lang) =>
    allDocsSlugs(region).map((slug) => ({ lang, slug })),
  );
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ lang: string; slug: string[] }>;
}): Promise<Metadata> {
  const { lang, slug } = await params;
  if (!isLocalePath(lang) || slug.length === 0) return {};
  const messages = MESSAGES[lang];
  const origin = getConfiguredSiteOrigin();
  const region = docsRegionFromOrigin(origin);

  try {
    const resolved = resolveDocsSlug(slug, region);
    if (resolved.kind === 's3-redirect') {
      const title = docTitle(lang, 's3');
      const canonicalPath = localizedDocsHref(lang, 's3', 'overview');
      const seoTitle = lang === 'zh' ? `${SITE_NAME.zh}${title} - 文档` : `${SITE_NAME.en} ${title} - Docs`;
      return {
        title: { absolute: seoTitle },
        description: messages.metadata.description,
        alternates: localizedAlternates(lang, (locale) => localizedDocsHref(locale, 's3', 'overview'), origin),
      };
    }
    const source = readDocsFromSlug(region, localePathToDocsLocale(lang), slug).source;
    const title = docTitleFromSlug(lang, slug);
    const description = slug[0] === 'intro'
      ? messages.metadata.description
      : markdownDescription(source, messages.metadata.description);
    const canonicalPath = canonicalDocsPath(lang, slug);
    const seoTitle = lang === 'zh' ? `${SITE_NAME.zh}${title} - 文档` : `${SITE_NAME.en} ${title} - Docs`;
    return {
      title: { absolute: seoTitle },
      description,
      alternates: localizedAlternates(lang, (locale) => {
        if (slug[0] === 's3' && slug[1]) {
          return `/${locale}/docs/s3/${slug[1]}`;
        }
        return localizedDocsHref(locale, slug[0] as DocsDocId);
      }, origin),
      openGraph: {
        type: 'article',
        locale: SITE_LOCALE[lang],
        alternateLocale: lang === 'zh' ? [SITE_LOCALE.en] : [SITE_LOCALE.zh],
        url: absoluteUrl(canonicalPath, origin),
        siteName: SITE_NAME[lang],
        title: seoTitle,
        description,
        images: [{ url: absoluteUrl(DEFAULT_OG_IMAGE, origin), alt: `${title} - ${SITE_NAME[lang]}` }],
      },
      twitter: {
        card: 'summary_large_image',
        title: seoTitle,
        description,
        images: [absoluteUrl(DEFAULT_OG_IMAGE, origin)],
      },
    };
  } catch {
    return {};
  }
}

export default async function LocalizedDocsPage({
  params,
}: {
  params: Promise<{ lang: string; slug: string[] }>;
}) {
  const { lang, slug } = await params;
  if (!isLocalePath(lang) || slug.length === 0) notFound();
  const origin = getConfiguredSiteOrigin();
  const region = docsRegionFromOrigin(origin);

  try {
    const resolved = resolveDocsSlug(slug, region);
    if (resolved.kind === 's3-redirect') {
      redirect(localizedDocsHref(lang, 's3', 'overview'));
    }
    const doc = readDocsFromSlug(region, localePathToDocsLocale(lang), slug);
    const activeDoc = slug[0] as DocsDocId;
    const activeSection = resolved.kind === 's3' ? resolved.section : undefined;

    return (
      <DocsReader
        doc={doc}
        initialDoc={activeDoc}
        initialS3Section={activeSection}
        localePath={lang}
        region={region}
      />
    );
  } catch {
    notFound();
  }
}
