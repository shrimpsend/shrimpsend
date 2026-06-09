'use client';

import Link from 'next/link';
import { Github } from 'lucide-react';
import { useEffect, useState } from 'react';
import { useI18n } from '@/contexts/I18nContext';
import { BrandLogo } from '@/components/brand/BrandLogo';
import { getApiUrl } from '@/lib/config';
import { OPEN_SOURCE_REPO_URL } from '@/lib/openSource';
import { localizedDocsHref, localizedHashHref, localeTagToPath } from '@/lib/i18nRouting';

const ICP_BEIAN_URL = 'https://beian.miit.gov.cn/#/Integrated/index';

function isMainlandCluster(): boolean {
  return !getApiUrl().toLowerCase().includes('shrimpsend.com');
}

export function SiteFooter() {
  const { localeTag, t } = useI18n();
  const [showIcp, setShowIcp] = useState(true);
  const localePath = localeTagToPath(localeTag);

  useEffect(() => {
    queueMicrotask(() => setShowIcp(isMainlandCluster()));
  }, []);

  return (
    <footer className="relative z-10 mx-auto flex w-full max-w-7xl flex-col gap-5 border-t border-white/10 px-5 py-8 text-sm text-muted-foreground md:flex-row md:items-center md:justify-between md:px-8">
      <div className="flex items-center gap-2">
        <BrandLogo size={28} alt={t('auth.brandAlt')} />
        <span>{t('common.brandName')}</span>
      </div>
      {showIcp ? (
        <div className="md:absolute md:left-1/2 md:-translate-x-1/2">
          <a
            href={ICP_BEIAN_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="text-xs transition-colors hover:text-foreground"
          >
            京ICP备2021038710号-13
          </a>
        </div>
      ) : null}
      <div className="flex flex-wrap gap-5">
        <Link href={localizedDocsHref(localePath, 'privacy')} target="_blank" rel="noopener noreferrer" className="hover:text-foreground">
          {t('auth.legalPrivacy')}
        </Link>
        <Link href={localizedDocsHref(localePath, 'terms')} target="_blank" rel="noopener noreferrer" className="hover:text-foreground">
          {t('auth.legalTerms')}
        </Link>
        <Link href={localizedHashHref(localePath, 'faq')} className="hover:text-foreground">
          {t('landing.navFaq')}
        </Link>
        <a
          href={OPEN_SOURCE_REPO_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-1.5 hover:text-foreground"
        >
          <Github className="size-3.5" />
          {t('common.sourceCode')}
        </a>
      </div>
    </footer>
  );
}
