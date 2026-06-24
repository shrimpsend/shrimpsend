'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import type { Components } from 'react-markdown';
import type { ComponentType, ReactNode } from 'react';
import { useMemo } from 'react';
import { useI18n } from '@/contexts/I18nContext';
import { localizedDocsHref, localizedHomeHref, parseDocsPathname, type LocalePath } from '@/lib/i18nRouting';
import { getClientReleaseDownloadUrl } from '@/lib/clientReleaseDownload';
import { SiteFooter } from '@/components/landing/SiteFooter';
import { SiteNav } from '@/components/landing/SiteNav';
import { buttonVariants } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { BookOpen, Download, FileText, Globe2, Mail, ScrollText, Settings2, ShieldCheck } from 'lucide-react';
import type { DocsDocId, DocsHeading, DocsMarkdownSource, DocsRegion, S3SectionId } from '@/lib/docsConfig';
import { s3SectionsForRegion } from '@/lib/docsConfig';
import { DocsCodeBlock } from '@/components/docs/docs-code-block';
import docsImageManifest from '@/lib/docsImageManifest.json';

type DocsImageManifest = Record<string, { width: number; height: number }>;

const docImageSizes = docsImageManifest as DocsImageManifest;

const docImageClassName =
  'mx-auto block h-auto w-auto max-w-[min(100%,42rem)] rounded-2xl border border-white/10 bg-black/10 object-contain shadow-sm';

function DocsMarkdownImage({ src, alt, ...props }: React.ComponentProps<'img'>) {
  const srcStr = typeof src === 'string' ? src : undefined;
  const isDocPng = Boolean(srcStr?.startsWith('/docs/') && /\.png$/i.test(srcStr));
  const webpSrc = isDocPng && srcStr ? srcStr.replace(/\.png$/i, '.webp') : undefined;
  const dimensions = srcStr ? docImageSizes[srcStr] : undefined;

  const img = (
    /* eslint-disable-next-line @next/next/no-img-element */
    <img
      src={srcStr}
      alt={alt ?? ''}
      className={docImageClassName}
      loading="lazy"
      width={dimensions?.width}
      height={dimensions?.height}
      {...props}
    />
  );

  return (
    <figure className="my-6 flex flex-col items-center">
      {webpSrc ? (
        <picture>
          <source type="image/webp" srcSet={webpSrc} />
          {img}
        </picture>
      ) : (
        img
      )}
      {alt ? (
        <figcaption className="mt-2 text-center text-xs leading-5 text-muted-foreground">{alt}</figcaption>
      ) : null}
    </figure>
  );
}

const docItems: Array<{ id: DocsDocId; labelKey: string; icon: ComponentType<{ className?: string }> }> = [
  { id: 'intro', labelKey: 'docs.nav.intro', icon: BookOpen },
  { id: 's3', labelKey: 'docs.nav.s3', icon: Settings2 },
  { id: 'privacy', labelKey: 'docs.nav.privacy', icon: ShieldCheck },
  { id: 'terms', labelKey: 'docs.nav.terms', icon: ScrollText },
  { id: 'contact', labelKey: 'docs.nav.contact', icon: Mail },
];

const s3SectionLabelKeys: Record<S3SectionId, string> = {
  overview: 'docs.nav.s3Overview',
  bitiful: 'docs.nav.s3Bitiful',
  'data-capsule': 'docs.nav.s3DataCapsule',
  'built-in': 'docs.nav.s3BuiltIn',
  'tencent-cos': 'docs.nav.s3TencentCos',
  'cloudflare-r2': 'docs.nav.s3CloudflareR2',
  rustfs: 'docs.nav.s3Rustfs',
};

function headingText(children: ReactNode): string {
  if (typeof children === 'string') return children;
  if (Array.isArray(children)) return children.map(headingText).join('');
  if (children && typeof children === 'object' && 'props' in children) {
    return headingText((children as { props?: { children?: ReactNode } }).props?.children);
  }
  return '';
}

function slugifyHeading(input: string): string {
  const base = input
    .replace(/[`*_~[\]()]/g, '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^\p{Letter}\p{Number}-]+/gu, '');
  return base || 'section';
}

function paragraphIsImageOnly(node: unknown): boolean {
  const p = node as { tagName?: string; children?: Array<{ type?: string; tagName?: string; value?: string }> } | undefined;
  if (p?.tagName !== 'p' || !p.children) return false;
  const meaningful = p.children.filter(
    (child) => child.type !== 'text' || (child.value?.trim() ?? '') !== '',
  );
  return meaningful.length === 1 && meaningful[0]?.type === 'element' && meaningful[0]?.tagName === 'img';
}

const markdownComponents: Components = {
  h1: ({ children, ...props }) => (
    <h1 className="mb-5 scroll-mt-24 text-3xl font-bold tracking-tight text-foreground sm:text-4xl" {...props}>
      {children}
    </h1>
  ),
  h2: ({ children, ...props }) => (
    <h2 id={slugifyHeading(headingText(children))} className="mb-3 mt-9 scroll-mt-24 text-2xl font-semibold tracking-tight text-foreground" {...props}>
      {children}
    </h2>
  ),
  h3: ({ children, ...props }) => (
    <h3 id={slugifyHeading(headingText(children))} className="mb-2 mt-7 scroll-mt-24 text-lg font-semibold text-foreground" {...props}>
      {children}
    </h3>
  ),
  p: ({ children, node, ...props }) => {
    if (paragraphIsImageOnly(node)) {
      return <div className="mb-4">{children}</div>;
    }
    return (
      <p className="mb-4 text-sm leading-7 text-foreground/88" {...props}>
        {children}
      </p>
    );
  },
  ul: ({ children, ...props }) => (
    <ul className="mb-4 list-disc space-y-1.5 pl-5 text-sm leading-7 text-foreground/88" {...props}>
      {children}
    </ul>
  ),
  ol: ({ children, ...props }) => (
    <ol className="mb-4 list-decimal space-y-1.5 pl-5 text-sm leading-7 text-foreground/88" {...props}>
      {children}
    </ol>
  ),
  li: ({ children, ...props }) => (
    <li className="marker:text-primary/70" {...props}>
      {children}
    </li>
  ),
  a: ({ children, href, ...props }) => (
    <a
      href={href}
      className="font-semibold text-[var(--docs-link)] underline decoration-[var(--docs-link-decoration)] underline-offset-4 transition-colors hover:text-[var(--docs-link-hover)] hover:decoration-[var(--docs-link-hover)]"
      rel="noopener noreferrer"
      {...props}
    >
      {children}
    </a>
  ),
  blockquote: ({ children, ...props }) => (
    <blockquote className="mb-4 rounded-2xl border border-primary/20 bg-primary/[0.08] px-4 py-3 text-sm text-muted-foreground" {...props}>
      {children}
    </blockquote>
  ),
  hr: (props) => <hr className="my-8 border-white/10" {...props} />,
  table: ({ children, ...props }) => (
    <div className="mb-4 overflow-x-auto rounded-2xl border border-white/10">
      <table className="w-full min-w-[560px] border-collapse text-left text-sm" {...props}>
        {children}
      </table>
    </div>
  ),
  thead: ({ children, ...props }) => <thead className="bg-white/[0.06] text-foreground" {...props}>{children}</thead>,
  th: ({ children, ...props }) => (
    <th className="border-b border-white/10 px-3 py-2 font-semibold" {...props}>
      {children}
    </th>
  ),
  td: ({ children, ...props }) => (
    <td className="border-b border-white/10 px-3 py-2 align-top text-foreground/88" {...props}>
      {children}
    </td>
  ),
  tr: ({ children, ...props }) => <tr className="last:[&>td]:border-b-0" {...props}>{children}</tr>,
  code: ({ className, children, ...props }) => {
    const isFenced = Boolean(className?.startsWith('language-'));
    if (isFenced) return <code className={className} {...props}>{children}</code>;
    return <code className="rounded bg-white/[0.08] px-1 py-0.5 font-mono text-[0.85em]" {...props}>{children}</code>;
  },
  pre: ({ children, ...props }) => (
    <DocsCodeBlock {...props}>{children}</DocsCodeBlock>
  ),
  strong: ({ children, ...props }) => <strong className="font-semibold text-foreground" {...props}>{children}</strong>,
  img: DocsMarkdownImage,
};

export function DocsReader({
  doc,
  initialDoc,
  initialS3Section,
  localePath,
  region,
}: {
  doc: DocsMarkdownSource;
  initialDoc: DocsDocId;
  initialS3Section?: S3SectionId;
  localePath: LocalePath;
  region: DocsRegion;
}) {
  const { t } = useI18n();
  const pathname = usePathname();
  const routeFromPath = useMemo(() => parseDocsPathname(pathname), [pathname]);
  const activeDoc = routeFromPath?.doc ?? initialDoc;
  const activeS3Section = routeFromPath?.s3Section ?? initialS3Section ?? doc.section;
  const activeItem = docItems.find((item) => item.id === activeDoc) ?? docItems[0]!;
  const ActiveIcon = activeItem.icon;
  const releaseHref = getClientReleaseDownloadUrl();
  const s3Sections = useMemo(() => s3SectionsForRegion(region), [region]);
  const isS3Active = activeDoc === 's3';

  const headings = useMemo<DocsHeading[]>(() => doc.headings, [doc]);

  const badgeLabel = isS3Active && activeS3Section
    ? `${t(activeItem.labelKey)} · ${t(s3SectionLabelKeys[activeS3Section])}`
    : t(activeItem.labelKey);

  return (
    <main className="landing-shell min-h-dvh text-foreground">
      <SiteNav active="docs" />

      <div className="mx-auto grid w-full max-w-[1440px] gap-6 px-5 pb-8 lg:grid-cols-[260px_minmax(0,1fr)_260px] lg:px-8">
        <aside className="hidden lg:block">
          <div className="sticky top-5 space-y-5">
            <nav className="landing-glass-card rounded-3xl p-3" aria-label={t('docs.nav.label')}>
              <p className="px-3 py-2 font-mono text-[10px] uppercase tracking-[0.24em] text-muted-foreground">
                {region === 'overseas' ? t('docs.nav.regionOverseas') : t('docs.nav.regionMainland')}
              </p>
              <div className="space-y-1">
                {docItems.map(({ id, labelKey, icon: Icon }) => (
                  <div key={id}>
                    <Link
                      href={localizedDocsHref(localePath, id)}
                      className={cn(
                        'flex w-full items-center gap-2.5 rounded-2xl px-3 py-2 text-left text-sm transition-colors',
                        activeDoc === id
                          ? 'bg-primary/12 text-foreground ring-1 ring-primary/20'
                          : 'text-muted-foreground hover:bg-white/[0.06] hover:text-foreground',
                      )}
                    >
                      <Icon className="size-4 text-primary/80" />
                      {t(labelKey)}
                    </Link>
                    {id === 's3' && isS3Active ? (
                      <div className="ml-2 mt-1 space-y-0.5 border-l border-white/10 pl-2">
                        {s3Sections.map((sectionId) => (
                          <Link
                            key={sectionId}
                            href={localizedDocsHref(localePath, 's3', sectionId)}
                            className={cn(
                              'block rounded-xl px-3 py-1.5 text-xs transition-colors',
                              isS3Active && activeS3Section === sectionId
                                ? 'bg-primary/10 font-medium text-foreground'
                                : 'text-muted-foreground hover:bg-white/[0.06] hover:text-foreground',
                            )}
                          >
                            {t(s3SectionLabelKeys[sectionId])}
                          </Link>
                        ))}
                      </div>
                    ) : null}
                  </div>
                ))}
              </div>
            </nav>

            <div className="landing-glass-card rounded-3xl p-4">
              <p className="font-mono text-[10px] uppercase tracking-[0.24em] text-muted-foreground">{t('docs.nav.actions')}</p>
              <div className="mt-3 space-y-2">
                <a href={releaseHref} target="_blank" rel="noopener noreferrer" className={cn(buttonVariants(), 'h-10 w-full rounded-2xl')}>
                  <Download className="size-4" />
                  {t('landing.downloadPrimary')}
                </a>
                <Link href="/chat" className={cn(buttonVariants(), 'h-10 w-full rounded-2xl')}>
                  <Globe2 className="size-4" />
                  {t('landing.openApp')}
                </Link>
                <Link href={localizedHomeHref(localePath)} className={cn(buttonVariants({ variant: 'outline' }), 'h-10 w-full rounded-2xl bg-white/[0.04]')}>
                  <FileText className="size-4" />
                  {t('docs.nav.backHome')}
                </Link>
              </div>
            </div>
          </div>
        </aside>

        <div className="min-w-0">
          <div className="mb-4 flex gap-2 overflow-x-auto pb-1 lg:hidden">
            {docItems.map(({ id, labelKey }) => (
              <Link
                key={id}
                href={localizedDocsHref(localePath, id)}
                className={cn(
                  'shrink-0 rounded-full border px-3 py-1.5 text-sm',
                  activeDoc === id ? 'border-primary/40 bg-primary/12 text-foreground' : 'border-white/10 text-muted-foreground',
                )}
              >
                {t(labelKey)}
              </Link>
            ))}
          </div>

          {isS3Active ? (
            <div className="mb-4 flex gap-2 overflow-x-auto pb-1 lg:hidden">
              {s3Sections.map((sectionId) => (
                <Link
                  key={sectionId}
                  href={localizedDocsHref(localePath, 's3', sectionId)}
                  className={cn(
                    'shrink-0 rounded-full border px-3 py-1.5 text-xs',
                    activeS3Section === sectionId
                      ? 'border-primary/40 bg-primary/12 text-foreground'
                      : 'border-white/10 text-muted-foreground',
                  )}
                >
                  {t(s3SectionLabelKeys[sectionId])}
                </Link>
              ))}
            </div>
          ) : null}

          <div className="mb-4 grid grid-cols-2 gap-2 lg:hidden">
            <a href={releaseHref} target="_blank" rel="noopener noreferrer" className={cn(buttonVariants(), 'h-10 rounded-2xl')}>
              <Download className="size-4" />
              {t('landing.downloadPrimary')}
            </a>
            <Link href="/chat" className={cn(buttonVariants({ variant: 'outline' }), 'h-10 rounded-2xl bg-white/[0.04]')}>
              <Globe2 className="size-4" />
              {t('landing.openApp')}
            </Link>
          </div>

          <article className="docs-markdown landing-glass-card rounded-[2rem] p-6 sm:p-8">
            <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-primary/20 bg-primary/[0.08] px-3 py-1.5 text-xs font-medium text-primary">
              <ActiveIcon className="size-3.5" />
              {badgeLabel}
            </div>
            <ReactMarkdown remarkPlugins={[remarkGfm]} components={markdownComponents}>
              {doc.source}
            </ReactMarkdown>
          </article>
        </div>

        <aside className="hidden xl:block">
          <div className="sticky top-5 space-y-5">
            <div className="landing-glass-card rounded-3xl p-4">
              <p className="font-mono text-[10px] uppercase tracking-[0.24em] text-muted-foreground">
                {t('docs.index.title')}
              </p>
              <div className="mt-3 space-y-2">
                {headings.length === 0 ? (
                  <p className="text-sm text-muted-foreground">{t('docs.index.empty')}</p>
                ) : (
                  headings.map((heading) => (
                    <a
                      key={heading.id}
                      href={`#${heading.id}`}
                      className={cn(
                        'block text-sm text-muted-foreground transition-colors hover:text-foreground',
                        heading.depth === 3 && 'pl-3 text-xs',
                      )}
                    >
                      {heading.title}
                    </a>
                  ))
                )}
              </div>
            </div>

            <div className="landing-glass-card rounded-3xl p-4">
              <p className="font-mono text-[10px] uppercase tracking-[0.24em] text-muted-foreground">{t('docs.index.current')}</p>
              <p className="mt-2 text-sm font-medium text-foreground">{badgeLabel}</p>
              <p className="mt-1 text-xs leading-5 text-muted-foreground">
                {region === 'overseas' ? t('docs.index.overseasOnly') : t('docs.index.mainlandOnly')}
              </p>
            </div>
          </div>
        </aside>
      </div>
      <SiteFooter />
    </main>
  );
}
