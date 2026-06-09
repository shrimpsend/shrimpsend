'use client';

import { Github } from 'lucide-react';
import { BrandLogo } from '@/components/brand/BrandLogo';
import { Card, CardContent } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { useI18n } from '@/contexts/I18nContext';
import { OPEN_SOURCE_REPO_URL } from '@/lib/openSource';
import { SETTINGS_APP_VERSION } from './constants';

export function AboutPanel() {
  const { t } = useI18n();
  return (
    <Card>
      <CardContent className="pt-4 pb-4">
        <div className="flex justify-center mb-3">
          <BrandLogo size={72} alt={t('common.brandName')} />
        </div>
        <p className="text-sm">{t('common.brandName')}</p>
        <p className="text-xs text-muted-foreground mt-1">{t('common.brandTagline')}</p>
        <Separator className="my-2" />
        <p className="text-xs text-muted-foreground">{t('about.versionLine', { version: SETTINGS_APP_VERSION })}</p>
        <a
          href={OPEN_SOURCE_REPO_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="mt-3 inline-flex items-start gap-2 text-xs text-muted-foreground transition-colors hover:text-foreground"
        >
          <Github className="mt-0.5 size-3.5 shrink-0" />
          <span>
            <span className="block font-medium">{t('common.sourceCode')}</span>
            <span className="mt-0.5 block text-[11px] opacity-80">{t('about.sourceCodeSubtitle')}</span>
          </span>
        </a>
      </CardContent>
    </Card>
  );
}
