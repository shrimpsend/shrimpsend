'use client';

import { useEffect, useState } from 'react';
import { BrandLogo } from '@/components/brand/BrandLogo';
import { useI18n } from '@/contexts/I18nContext';
import { getClientReleaseDownloadUrl, isClientDownloadOverseas } from '@/lib/clientReleaseDownload';
import { cn } from '@/lib/utils';
import { buttonVariants } from '@/components/ui/button';
import type { LucideIcon } from 'lucide-react';
import {
  Download,
  RefreshCw,
  Cpu,
  Layers,
  Radio,
  Cable,
  CloudUpload,
  Sparkles,
  Globe2,
  Router,
} from 'lucide-react';

type Props = {
  className?: string;
};

type FeatureItem = { icon: LucideIcon; titleKey: string; descKey: string; stagger: string };

export function LoginLandingHero({ className }: Props) {
  const { t } = useI18n();
  const [releaseHref, setReleaseHref] = useState(() => getClientReleaseDownloadUrl());
  const [overseas, setOverseas] = useState(() => isClientDownloadOverseas());

  useEffect(() => {
    queueMicrotask(() => {
      setReleaseHref(getClientReleaseDownloadUrl());
      setOverseas(isClientDownloadOverseas());
    });
  }, []);

  /** 核心：免安装、续传、复杂网络 */
  const primaryFeatures: FeatureItem[] = [
    { icon: Globe2, titleKey: 'landing.featureNoInstallTitle', descKey: 'landing.featureNoInstallDesc', stagger: 'app-stagger-1' },
    { icon: RefreshCw, titleKey: 'landing.featureResumeTitle', descKey: 'landing.featureResumeDesc', stagger: 'app-stagger-2' },
    { icon: Router, titleKey: 'landing.featureRestrictiveNetworkTitle', descKey: 'landing.featureRestrictiveNetworkDesc', stagger: 'app-stagger-3' },
  ];

  /** 更多：本地发现、并发与传输栈、进阶能力与体验 */
  const secondaryFeatures: FeatureItem[] = [
    { icon: Radio, titleKey: 'landing.featureOfflineMdnsTitle', descKey: 'landing.featureOfflineMdnsDesc', stagger: 'app-stagger-4' },
    { icon: Layers, titleKey: 'landing.featureMultiParallelTitle', descKey: 'landing.featureMultiParallelDesc', stagger: 'app-stagger-5' },
    { icon: Cpu, titleKey: 'landing.featureMultiThreadTitle', descKey: 'landing.featureMultiThreadDesc', stagger: 'app-stagger-6' },
    { icon: Cable, titleKey: 'landing.featureWebrtcTitle', descKey: 'landing.featureWebrtcDesc', stagger: 'app-stagger-7' },
    { icon: CloudUpload, titleKey: 'landing.featureS3WanTitle', descKey: 'landing.featureS3WanDesc', stagger: 'app-stagger-8' },
    { icon: Sparkles, titleKey: 'landing.featureMinimalUiTitle', descKey: 'landing.featureMinimalUiDesc', stagger: 'app-stagger-9' },
  ];

  return (
    <div className={cn('relative flex flex-col gap-10', className)}>
      <div className="pointer-events-none absolute -right-[20%] -top-[8%] h-[min(48vw,380px)] w-[min(48vw,380px)] rounded-full opacity-35 blur-3xl motion-safe:animate-app-glow-drift md:-right-[12%] md:-top-[12%]" aria-hidden style={{
        background:
          'radial-gradient(circle at 35% 35%, color-mix(in oklch, var(--chart-2) 38%, transparent), transparent 65%)',
      }}
      />

      <header className="relative space-y-4 animate-app-fade-up">
        <div className="flex items-center gap-3">
          <BrandLogo
            size={44}
            alt={t('auth.brandAlt')}
            className="shrink-0 shadow-md ring-1 ring-border/60"
            priority
          />
          <span className="font-display text-lg font-semibold tracking-tight text-foreground/90">{t('common.brandName')}</span>
        </div>
        <h2 className="font-display max-w-xl text-balance text-3xl font-semibold leading-[1.15] tracking-tight text-foreground sm:text-4xl md:text-[2.35rem]">
          {t('landing.headline')}
        </h2>
        <p className="max-w-xl text-pretty text-base leading-relaxed text-muted-foreground sm:text-lg">{t('landing.subhead')}</p>
      </header>

      <div className="relative space-y-8">
        <section className="space-y-3">
          <h3 className="font-display text-sm font-semibold tracking-tight text-foreground">{t('landing.featuresPrimaryTitle')}</h3>
          <ul className="grid gap-2.5 sm:gap-3 lg:grid-cols-2 lg:gap-x-3 lg:gap-y-2.5">
            {primaryFeatures.map(({ icon: Icon, titleKey, descKey, stagger }) => (
              <li
                key={titleKey}
                className={cn(
                  'surface-glass flex gap-3 rounded-xl px-3.5 py-3 motion-safe:animate-app-fade-up sm:gap-3.5 sm:px-4 sm:py-3.5',
                  stagger,
                )}
              >
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-primary/12 text-primary ring-1 ring-primary/20 sm:h-11 sm:w-11 sm:rounded-xl">
                  <Icon className="h-[1.125rem] w-[1.125rem] sm:h-5 sm:w-5" aria-hidden />
                </span>
                <div className="min-w-0 space-y-0.5">
                  <p className="text-sm font-semibold leading-tight text-foreground">{t(titleKey)}</p>
                  <p className="text-xs leading-snug text-muted-foreground sm:text-[13px]">{t(descKey)}</p>
                </div>
              </li>
            ))}
          </ul>
        </section>

        <section className="space-y-2.5">
          <h3 className="font-display text-xs font-medium tracking-tight text-muted-foreground">{t('landing.featuresSecondaryTitle')}</h3>
          <ul className="grid gap-2 sm:grid-cols-2 sm:gap-x-3 sm:gap-y-2">
            {secondaryFeatures.map(({ icon: Icon, titleKey, descKey, stagger }) => (
              <li
                key={titleKey}
                className={cn(
                  'flex gap-2.5 rounded-lg border border-border/45 bg-muted/20 px-3 py-2.5 motion-safe:animate-app-fade-up dark:bg-muted/15',
                  stagger,
                )}
              >
                <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-muted/55 text-muted-foreground dark:bg-muted/40">
                  <Icon className="h-3.5 w-3.5" aria-hidden />
                </span>
                <div className="min-w-0 space-y-0.5">
                  <p className="text-xs font-medium leading-tight text-muted-foreground">{t(titleKey)}</p>
                  <p className="text-[11px] leading-snug text-muted-foreground/85">{t(descKey)}</p>
                </div>
              </li>
            ))}
          </ul>
        </section>
      </div>

      <section className="relative space-y-3 motion-safe:animate-app-fade-up app-stagger-10">
        <div>
          <h3 className="font-display text-base font-semibold text-foreground">{t('landing.downloadsTitle')}</h3>
          <p className="mt-1 max-w-md text-xs leading-snug text-muted-foreground">{t('landing.downloadsHint')}</p>
        </div>

        <a
          href={releaseHref}
          target="_blank"
          rel="noopener noreferrer"
          className={cn(buttonVariants({ variant: 'outline', size: 'sm' }), 'gap-1.5')}
        >
          <Download className="h-4 w-4" />
          {overseas ? t('auth.downloadReleasesGithub') : t('auth.downloadReleasesGitee')}
        </a>
      </section>
    </div>
  );
}
