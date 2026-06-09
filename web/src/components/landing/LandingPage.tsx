'use client';

import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';
import { useI18n } from '@/contexts/I18nContext';
import { getClientReleaseDownloadUrl, isClientDownloadOverseas } from '@/lib/clientReleaseDownload';
import { LandingShowcaseImage } from '@/components/landing/LandingShowcaseImage';
import { SiteFooter } from '@/components/landing/SiteFooter';
import { SiteNav } from '@/components/landing/SiteNav';
import { buttonVariants } from '@/components/ui/button';
import type { LocalePath } from '@/lib/i18nRouting';
import { DEFAULT_OG_IMAGE, HREFLANG, SITE_NAME, absoluteUrl } from '@/lib/seo';
import { cn } from '@/lib/utils';
import {
  Check,
  Github,
  FileArchive,
  FileImage,
  Globe2,
  Laptop,
  Play,
  RefreshCw,
  Router,
  Server,
  Smartphone,
  Sparkles,
  X,
  Zap,
} from 'lucide-react';

const featureCards = [
  {
    icon: Globe2,
    titleKey: 'landing.featureNoInstallTitle',
    descKey: 'landing.featureNoInstallDesc',
  },
  {
    icon: RefreshCw,
    titleKey: 'landing.featureResumeTitle',
    descKey: 'landing.featureResumeDesc',
  },
  {
    icon: Router,
    titleKey: 'landing.featureRestrictiveNetworkTitle',
    descKey: 'landing.featureRestrictiveNetworkDesc',
  },
] as const;

const statItems = [
  { icon: Zap, valueKey: 'landing.statSpeedValue', labelKey: 'landing.statSpeedLabel' },
  { icon: RefreshCw, valueKey: 'landing.statSecurityValue', labelKey: 'landing.statSecurityLabel' },
  { icon: Globe2, valueKey: 'landing.statPlatformValue', labelKey: 'landing.statPlatformLabel' },
  { icon: Router, valueKey: 'landing.statMessageValue', labelKey: 'landing.statMessageLabel' },
] as const;

const compareScenarios = [
  {
    titleKey: 'landing.compareScenario1Title',
    othersKey: 'landing.compareScenario1Others',
    shrimpSendKey: 'landing.compareScenario1ShrimpSend',
  },
  {
    titleKey: 'landing.compareScenario2Title',
    othersKey: 'landing.compareScenario2Others',
    shrimpSendKey: 'landing.compareScenario2ShrimpSend',
  },
  {
    titleKey: 'landing.compareScenario3Title',
    othersKey: 'landing.compareScenario3Others',
    shrimpSendKey: 'landing.compareScenario3ShrimpSend',
  },
] as const;

const steps = [
  { icon: Laptop, titleKey: 'landing.stepOneTitle', descKey: 'landing.stepOneDesc' },
  { icon: Router, titleKey: 'landing.stepTwoTitle', descKey: 'landing.stepTwoDesc' },
  { icon: RefreshCw, titleKey: 'landing.stepThreeTitle', descKey: 'landing.stepThreeDesc' },
] as const;

const faqItems = [
  { q: 'landing.faqOfflineQ', a: 'landing.faqOfflineA' },
  { q: 'landing.faqLanLoginQ', a: 'landing.faqLanLoginA' },
  { q: 'landing.faqWebQ', a: 'landing.faqWebA' },
  { q: 'landing.faqS3Q', a: 'landing.faqS3A' },
] as const;

const pricingPlans = [
  {
    id: 'free-mainland',
    region: 'mainland',
    isFree: true,
    nameKey: 'landing.pricingPlanFreeName',
    priceKey: 'landing.pricingFreePrice',
    secondaryKey: 'landing.pricingDomesticFreeLine',
    devices: 3,
    featureKeys: ['landing.pricingFeatureNoPurchase', 'landing.pricingFeatureLanS3'],
    popular: false,
  },
  {
    id: 'free-overseas',
    region: 'overseas',
    isFree: true,
    nameKey: 'landing.pricingPlanFreeName',
    priceKey: 'landing.pricingFreePrice',
    secondaryKey: 'landing.pricingOverseasFreeLine',
    devices: 3,
    uploadGib: 1,
    featureKeys: ['landing.pricingFeatureUpload', 'landing.pricingFeatureLanS3'],
    popular: false,
  },
  {
    id: 'mini',
    region: 'mainland',
    name: 'Mini',
    price: '¥30',
    suffixKey: 'landing.pricingLifetimeSuffix',
    secondaryKey: 'landing.pricingDomesticMiniLine',
    devices: 6,
    featureKeys: ['landing.pricingFeatureLifetime', 'landing.pricingFeatureLanS3'],
    popular: false,
  },
  {
    id: 'domestic-pro',
    region: 'mainland',
    name: 'Pro',
    price: '¥60',
    suffixKey: 'landing.pricingLifetimeSuffix',
    secondaryKey: 'landing.pricingDomesticProLine',
    devices: 12,
    featureKeys: ['landing.pricingFeatureLifetime', 'landing.pricingFeatureAddon'],
    popular: true,
  },
  {
    id: 'plus',
    region: 'overseas',
    name: 'Plus',
    price: '$5.99',
    suffixKey: 'landing.pricingPerMonth',
    secondaryKey: 'landing.pricingOverseasPlusLine',
    devices: 10,
    uploadGib: 80,
    featureKeys: ['landing.pricingFeatureUpload', 'landing.pricingFeatureLanS3'],
    popular: false,
  },
  {
    id: 'pro',
    region: 'overseas',
    name: 'Pro',
    price: '$11.99',
    suffixKey: 'landing.pricingPerMonth',
    secondaryKey: 'landing.pricingOverseasProLine',
    devices: 20,
    uploadGib: 250,
    featureKeys: ['landing.pricingFeatureUpload', 'landing.pricingFeatureLanS3'],
    popular: true,
  },
  {
    id: 'ultra',
    region: 'overseas',
    name: 'Ultra',
    price: '$24.99',
    suffixKey: 'landing.pricingPerMonth',
    secondaryKey: 'landing.pricingOverseasUltraLine',
    devices: 50,
    uploadGib: 800,
    featureKeys: ['landing.pricingFeatureUpload', 'landing.pricingFeatureLanS3'],
    popular: false,
  },
] as const;

function getPricingRegion(siteOrigin: string): 'mainland' | 'overseas' {
  return isClientDownloadOverseas({ siteOrigin }) ? 'overseas' : 'mainland';
}

function GlowOrb({ className }: { className?: string }) {
  return <div className={cn('landing-glow-orb motion-safe:animate-app-glow-drift', className)} aria-hidden />;
}

function HeroVisual() {
  const { t } = useI18n();
  const devices = [
    { icon: Laptop, name: 'MacBook Pro', meta: t('landing.heroDeviceLocal'), active: true },
    { icon: Smartphone, name: 'iPhone 15', meta: t('landing.heroDeviceOnline'), active: true },
    { icon: Globe2, name: 'Web', meta: t('landing.heroDeviceBrowser'), active: false },
  ] as const;

  return (
    <div className="relative mx-auto h-[460px] w-full max-w-[600px] lg:h-[540px]">
      <div className="landing-orbit landing-orbit-1" aria-hidden />
      <div className="landing-orbit landing-orbit-2" aria-hidden />

      <div className="landing-device-card absolute left-[3%] top-[7%] w-[min(76vw,315px)] rounded-3xl p-4 shadow-2xl motion-safe:animate-app-fade-up">
        <div className="mb-4 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="size-2.5 rounded-full bg-primary shadow-[0_0_16px_color-mix(in_oklch,var(--primary)_80%,transparent)]" />
            <span className="font-mono text-[11px] text-foreground/80">{t('landing.heroPanelTitle')}</span>
          </div>
          <span className="rounded-full bg-primary/12 px-2 py-0.5 font-mono text-[10px] text-primary">
            {t('landing.heroPanelBadge')}
          </span>
        </div>

        <div className="rounded-2xl border border-primary/20 bg-primary/[0.08] px-4 py-3">
          <div className="flex items-start gap-3">
            <span className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-primary/15 text-primary ring-1 ring-primary/25">
              <RefreshCw className="size-4" />
            </span>
            <div>
              <p className="text-sm font-semibold text-foreground">{t('landing.heroMessageTitle')}</p>
              <p className="mt-1 text-xs leading-5 text-muted-foreground">{t('landing.heroMessageDesc')}</p>
            </div>
          </div>
        </div>

        <div className="mt-4 space-y-2.5">
          {devices.map(({ icon: Icon, name, meta, active }) => (
            <div key={name} className="flex items-center gap-3 rounded-2xl bg-white/[0.07] px-3 py-2.5 ring-1 ring-white/[0.08]">
              <span className="flex size-8 items-center justify-center rounded-xl bg-primary/12 text-primary">
                <Icon className="size-4" />
              </span>
              <div className="min-w-0 flex-1">
                <p className="truncate text-xs font-medium text-foreground/90">{name}</p>
                <p className="font-mono text-[10px] text-muted-foreground">{meta}</p>
              </div>
              <span className={cn('size-2.5 rounded-full', active ? 'bg-primary shadow-[0_0_12px_var(--primary)]' : 'bg-muted-foreground/35')} />
            </div>
          ))}
        </div>
      </div>

      <div className="landing-device-card absolute right-[2%] top-[18%] hidden w-[230px] rotate-[5deg] rounded-3xl p-4 shadow-2xl sm:block">
        <div className="mb-3 flex items-center justify-between">
          <span className="font-mono text-[10px] text-muted-foreground">{t('landing.heroPathTitle')}</span>
          <Router className="size-4 text-primary" />
        </div>
        <div className="space-y-2.5">
          <div className="rounded-2xl border border-primary/18 bg-primary/[0.09] px-3 py-2">
            <p className="text-xs font-semibold">{t('landing.heroPathLan')}</p>
            <p className="font-mono text-[10px] text-muted-foreground">WebRTC / LAN</p>
          </div>
          <div className="rounded-2xl bg-white/[0.06] px-3 py-2 ring-1 ring-white/[0.08]">
            <p className="text-xs font-semibold">{t('landing.heroPathS3')}</p>
            <p className="font-mono text-[10px] text-muted-foreground">S3 compatible</p>
          </div>
        </div>
      </div>

      <div className="landing-device-card absolute bottom-[13%] right-[4%] w-[min(70vw,265px)] rounded-3xl p-4 shadow-2xl motion-safe:animate-app-fade-up app-stagger-3">
        <div className="flex items-center gap-3 rounded-2xl bg-white/[0.07] px-3 py-2.5 ring-1 ring-white/[0.08]">
          <span className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-primary/12 text-primary">
            <FileImage className="size-4" />
          </span>
          <div className="min-w-0 flex-1">
            <p className="truncate text-xs font-semibold">project-build.apk</p>
            <p className="font-mono text-[10px] text-muted-foreground">{t('landing.heroResumeLabel')}</p>
          </div>
          <RefreshCw className="size-4 text-primary" />
        </div>
        <div className="mt-3 h-1.5 overflow-hidden rounded-full bg-white/12">
          <div className="h-full w-[68%] rounded-full bg-primary shadow-[0_0_18px_color-mix(in_oklch,var(--primary)_80%,transparent)]" />
        </div>
        <p className="mt-3 text-center text-xs font-medium text-muted-foreground">{t('landing.heroTransferStatus')}</p>
      </div>

      <div className="absolute bottom-[4%] left-[8%] flex items-center gap-3 rounded-3xl border border-white/12 bg-white/[0.07] px-4 py-3 shadow-2xl backdrop-blur-xl">
        <Server className="size-8 text-primary" />
        <div>
          <p className="text-xs font-semibold text-foreground">{t('landing.heroS3Title')}</p>
          <p className="font-mono text-[10px] text-muted-foreground">{t('landing.heroS3Desc')}</p>
        </div>
      </div>
    </div>
  );
}

function HowItWorksVisual() {
  const { t } = useI18n();
  const deviceCards = [
    {
      icon: Laptop,
      label: 'MacBook',
      status: t('landing.flowSending'),
      className: 'lg:translate-y-3',
    },
    {
      icon: Smartphone,
      label: 'iPhone',
      status: t('landing.flowSending'),
      className: 'lg:-translate-y-4',
    },
    {
      icon: Globe2,
      label: 'Web',
      status: t('landing.flowLinked'),
      className: 'lg:translate-y-3',
    },
  ] as const;

  const transferItems = [
    { icon: Globe2, label: 'browser', value: 'no install' },
    { icon: FileImage, label: 'project-build.apk', value: '68%' },
    { icon: FileArchive, label: 'release.zip', value: 'queued' },
  ] as const;

  return (
    <div className="landing-flow-panel relative min-h-[380px] overflow-hidden rounded-[2rem] p-5 sm:p-6">
      <div className="landing-beam" aria-hidden />
      <div className="pointer-events-none absolute left-[12%] top-[22%] h-24 w-[76%] rounded-full border border-primary/20 opacity-80 blur-[1px]" aria-hidden />
      <div className="pointer-events-none absolute inset-x-10 top-1/2 h-px bg-gradient-to-r from-transparent via-primary/70 to-transparent shadow-[0_0_28px_color-mix(in_oklch,var(--primary)_75%,transparent)]" aria-hidden />

      <div className="relative z-10 grid min-h-[320px] gap-4 lg:grid-cols-3">
        {deviceCards.map(({ icon: Icon, label, status, className }, index) => (
          <div
            key={label}
            className={cn(
              'landing-device-card relative flex min-h-60 flex-col justify-between overflow-hidden rounded-3xl p-4',
              className,
            )}
          >
            <div className="absolute inset-x-5 top-16 h-px bg-gradient-to-r from-transparent via-white/18 to-transparent" aria-hidden />
            <div className="flex items-center justify-between">
              <span className="flex size-10 items-center justify-center rounded-2xl bg-primary/12 text-primary ring-1 ring-primary/25">
                <Icon className="size-5" />
              </span>
              <span className={cn('size-2.5 rounded-full', index === 2 ? 'bg-muted-foreground/45' : 'bg-primary shadow-[0_0_14px_var(--primary)]')} />
            </div>

            <div className="space-y-2">
              {transferItems.slice(0, index === 1 ? 3 : 2).map(({ icon: ItemIcon, label: itemLabel, value }) => (
                <div key={itemLabel} className="flex items-center gap-2 rounded-2xl bg-white/[0.065] px-2.5 py-2 ring-1 ring-white/[0.07]">
                  <span className="flex size-7 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
                    <ItemIcon className="size-3.5" />
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-mono text-[10px] text-foreground/85">{itemLabel}</p>
                    <p className="font-mono text-[9px] text-muted-foreground">{value}</p>
                  </div>
                </div>
              ))}
            </div>

            <div>
              <p className="font-mono text-xs text-muted-foreground">{label}</p>
              <p className="mt-1 text-sm font-semibold">{status}</p>
            </div>
          </div>
        ))}
      </div>

      <div className="relative z-20 mt-4 grid gap-3 sm:grid-cols-3">
        <div className="rounded-2xl border border-primary/18 bg-primary/[0.08] px-3 py-2">
          <div className="flex items-center gap-2 text-xs font-semibold">
            <Router className="size-3.5 text-primary" />
            {t('landing.heroPathLan')}
          </div>
          <p className="mt-1 font-mono text-[10px] text-muted-foreground">WebRTC / LAN</p>
        </div>
        <div className="rounded-2xl border border-white/10 bg-white/[0.055] px-3 py-2">
          <div className="flex items-center gap-2 text-xs font-semibold">
            <RefreshCw className="size-3.5 text-primary" />
            {t('landing.heroTransferStatus')}
          </div>
          <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-white/12">
            <div className="h-full w-[68%] rounded-full bg-primary shadow-[0_0_16px_color-mix(in_oklch,var(--primary)_80%,transparent)]" />
          </div>
        </div>
        <div className="rounded-2xl border border-white/10 bg-white/[0.055] px-3 py-2">
          <div className="flex items-center gap-2 text-xs font-semibold">
            <Server className="size-3.5 text-primary" />
            {t('landing.heroPathS3')}
          </div>
          <p className="mt-1 font-mono text-[10px] text-muted-foreground">S3 fallback</p>
        </div>
      </div>
    </div>
  );
}

function CompareSection() {
  const { t } = useI18n();

  return (
    <section className="relative z-10 mx-auto w-full max-w-7xl px-5 pb-20 md:px-8" id="compare">
      <div className="mx-auto mb-10 max-w-2xl text-center">
        <p className="font-mono text-xs uppercase tracking-[0.3em] text-primary/80">{t('landing.compareKicker')}</p>
        <h2 className="font-display mt-3 text-3xl font-semibold tracking-tight sm:text-4xl">{t('landing.compareTitle')}</h2>
        <p className="mt-3 text-sm leading-7 text-muted-foreground">{t('landing.compareDesc')}</p>
      </div>
      <div className="grid gap-4 md:grid-cols-3">
        {compareScenarios.map(({ titleKey, othersKey, shrimpSendKey }) => (
          <article key={titleKey} className="landing-glass-card flex flex-col rounded-3xl p-5">
            <h3 className="text-base font-semibold tracking-tight">{t(titleKey)}</h3>
            <div className="mt-5 space-y-3">
              <div className="rounded-2xl border border-white/8 bg-white/[0.03] px-3.5 py-3">
                <p className="text-[11px] font-medium uppercase tracking-wide text-muted-foreground">
                  {t('landing.compareOthersLabel')}
                </p>
                <div className="mt-2 flex gap-2">
                  <X className="mt-0.5 size-4 shrink-0 text-muted-foreground/70" aria-hidden />
                  <p className="text-sm leading-6 text-muted-foreground">{t(othersKey)}</p>
                </div>
              </div>
              <div className="rounded-2xl border border-primary/25 bg-primary/[0.08] px-3.5 py-3">
                <p className="text-[11px] font-medium uppercase tracking-wide text-primary/80">
                  {t('landing.compareShrimpSendLabel')}
                </p>
                <div className="mt-2 flex gap-2">
                  <Check className="mt-0.5 size-4 shrink-0 text-primary" aria-hidden />
                  <p className="text-sm leading-6 text-foreground">{t(shrimpSendKey)}</p>
                </div>
              </div>
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}

function safeJsonLd(value: unknown): string {
  return JSON.stringify(value).replace(/</g, '\\u003c');
}

function LandingJsonLd({ localePath, siteOrigin }: { localePath: LocalePath; siteOrigin: string }) {
  const { t } = useI18n();
  const homeUrl = absoluteUrl(`/${localePath}`, siteOrigin);
  const logoUrl = absoluteUrl(DEFAULT_OG_IMAGE, siteOrigin);
  const language = HREFLANG[localePath];
  const graph = [
    {
      '@type': 'Organization',
      '@id': `${siteOrigin}/#organization`,
      name: SITE_NAME[localePath],
      url: siteOrigin,
      logo: logoUrl,
      sameAs: [homeUrl],
      contactPoint: {
        '@type': 'ContactPoint',
        contactType: 'customer support',
        url: absoluteUrl(`/${localePath}/docs/contact`, siteOrigin),
      },
    },
    {
      '@type': 'WebSite',
      '@id': `${siteOrigin}/#website`,
      name: SITE_NAME[localePath],
      url: siteOrigin,
      inLanguage: language,
      publisher: { '@id': `${siteOrigin}/#organization` },
      potentialAction: {
        '@type': 'ViewAction',
        target: absoluteUrl(`/${localePath}/docs/intro`, siteOrigin),
      },
    },
    {
      '@type': 'SoftwareApplication',
      '@id': `${homeUrl}#software`,
      name: SITE_NAME[localePath],
      applicationCategory: 'UtilitiesApplication',
      operatingSystem: 'macOS, Windows, Android, iOS, Web',
      url: homeUrl,
      image: logoUrl,
      description: t('landing.heroSubhead'),
      offers: {
        '@type': 'Offer',
        price: '0',
        priceCurrency: localePath === 'zh' ? 'CNY' : 'USD',
      },
    },
    {
      '@type': 'FAQPage',
      '@id': `${homeUrl}#faq`,
      inLanguage: language,
      mainEntity: faqItems.map((item) => ({
        '@type': 'Question',
        name: t(item.q),
        acceptedAnswer: {
          '@type': 'Answer',
          text: t(item.a),
        },
      })),
    },
  ];

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{
        __html: safeJsonLd({
          '@context': 'https://schema.org',
          '@graph': graph,
        }),
      }}
    />
  );
}

export function LandingPage({ localePath, siteOrigin }: { localePath: LocalePath; siteOrigin: string }) {
  const { t } = useI18n();
  const { accessToken } = useAuth();
  const pricingRegion = getPricingRegion(siteOrigin);
  const releaseHref = getClientReleaseDownloadUrl({ siteOrigin });
  const purchaseHref = accessToken ? '/settings/membership' : '/login?next=%2Fsettings%2Fmembership';
  const webTrialHref = accessToken ? '/chat' : '/login?next=%2Fchat';
  const visiblePricingPlans = pricingPlans.filter((plan) => plan.region === pricingRegion);

  return (
    <main className="landing-shell min-h-dvh overflow-hidden text-foreground">
      <LandingJsonLd localePath={localePath} siteOrigin={siteOrigin} />
      <GlowOrb className="-left-40 top-24 h-80 w-80" />
      <GlowOrb className="right-[-10rem] top-[28rem] h-[28rem] w-[28rem] opacity-45" />

      <SiteNav active="home" />

      <section className="relative z-10 mx-auto grid w-full max-w-7xl items-center gap-10 px-5 pb-12 pt-10 md:px-8 lg:grid-cols-[0.95fr_1.05fr] lg:pb-18 lg:pt-16">
        <div className="max-w-2xl motion-safe:animate-app-fade-up">
          <div className="mb-5 inline-flex items-center gap-2 rounded-full border border-primary/20 bg-primary/[0.08] px-3 py-1.5 text-xs font-medium text-primary shadow-lg shadow-primary/10">
            <Sparkles className="size-3.5" />
            {t('landing.eyebrow')}
          </div>
          <h1 className="font-display text-balance text-4xl font-semibold leading-[1.2] tracking-tight sm:text-5xl lg:text-6xl">
            {t('landing.heroTitleBefore')}
            {localePath === 'en' ? ' ' : null}
            <span className="landing-gradient-text block pb-4">{t('landing.heroTitleAccent')}</span>
          </h1>
          <p className="mt-6 max-w-xl text-pretty text-base leading-8 text-muted-foreground sm:text-lg">
            {t('landing.heroSubhead')}
          </p>
          <div className="mt-8 flex flex-col gap-3 sm:flex-row">
            <a
              href={releaseHref}
              target="_blank"
              rel="noopener noreferrer"
              className={cn(buttonVariants({ size: 'lg' }), 'h-12 rounded-2xl px-5 text-sm shadow-xl shadow-primary/20')}
            >
              <Github className="size-4" />
              {t('landing.downloadPrimary')}
            </a>
            <Link href={webTrialHref} className={cn(buttonVariants({ variant: 'outline', size: 'lg' }), 'h-12 rounded-2xl bg-white/[0.04] px-5')}>
              <Play className="size-4" />
              {accessToken ? t('landing.tryWeb') : t('landing.loginToTryWeb')}
            </Link>
          </div>
          <p className="mt-3 text-xs text-muted-foreground">{t('landing.heroFootnote')}</p>
        </div>

        <HeroVisual />
      </section>

      <LandingShowcaseImage />

      <section className="relative z-10 mx-auto w-full max-w-7xl px-5 md:px-8">
        <div className="grid overflow-hidden rounded-3xl border border-white/10 bg-white/[0.045] shadow-2xl shadow-black/20 backdrop-blur-2xl sm:grid-cols-2 lg:grid-cols-4">
          {statItems.map(({ icon: Icon, valueKey, labelKey }) => (
            <div key={valueKey} className="flex items-center gap-3 border-white/10 px-5 py-5 sm:border-r last:border-r-0">
              <span className="flex size-11 shrink-0 items-center justify-center rounded-2xl bg-primary/12 text-primary ring-1 ring-primary/25">
                <Icon className="size-5" />
              </span>
              <div>
                <p className="text-lg font-semibold leading-none">{t(valueKey)}</p>
                <p className="mt-1 text-xs text-muted-foreground">{t(labelKey)}</p>
              </div>
            </div>
          ))}
        </div>
      </section>

      <section className="relative z-10 mx-auto w-full max-w-7xl px-5 py-20 md:px-8" id="features">
        <div className="mx-auto mb-10 max-w-2xl text-center">
          <p className="font-mono text-xs uppercase tracking-[0.3em] text-primary/80">{t('landing.featuresKicker')}</p>
          <h2 className="font-display mt-3 text-3xl font-semibold tracking-tight sm:text-4xl">{t('landing.featuresTitle')}</h2>
        </div>
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {featureCards.map(({ icon: Icon, titleKey, descKey }) => (
            <article key={titleKey} className="landing-glass-card rounded-3xl p-5">
              <span className="mb-6 flex size-12 items-center justify-center rounded-2xl bg-primary/12 text-primary ring-1 ring-primary/20">
                <Icon className="size-5" />
              </span>
              <h3 className="text-base font-semibold tracking-tight">{t(titleKey)}</h3>
              <p className="mt-3 text-sm leading-6 text-muted-foreground">{t(descKey)}</p>
            </article>
          ))}
        </div>
      </section>

      <CompareSection />

      <section className="relative z-10 mx-auto grid w-full max-w-7xl gap-10 px-5 pb-20 md:px-8 lg:grid-cols-[0.8fr_1.2fr]">
        <div>
          <p className="font-mono text-xs uppercase tracking-[0.3em] text-primary/80">{t('landing.howKicker')}</p>
          <h2 className="font-display mt-3 text-3xl font-semibold tracking-tight">{t('landing.howTitle')}</h2>
          <div className="mt-8 space-y-4">
            {steps.map(({ icon: Icon, titleKey, descKey }, index) => (
              <div key={titleKey} className="flex gap-4">
                <span className="flex size-10 shrink-0 items-center justify-center rounded-2xl bg-primary/12 text-primary">
                  <Icon className="size-4" />
                </span>
                <div>
                  <h3 className="text-sm font-semibold">{index + 1}. {t(titleKey)}</h3>
                  <p className="mt-1 text-sm leading-6 text-muted-foreground">{t(descKey)}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
        <HowItWorksVisual />
      </section>

      <section className="relative z-10 mx-auto w-full max-w-7xl px-5 pb-20 md:px-8" id="pricing">
        <div className="mb-8 flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
          <div>
            <p className="font-mono text-xs uppercase tracking-[0.3em] text-primary/80">{t('landing.pricingKicker')}</p>
            <h2 className="font-display mt-3 text-3xl font-semibold tracking-tight sm:text-4xl">{t('landing.pricingTitle')}</h2>
            <p className="mt-3 max-w-2xl text-sm leading-7 text-muted-foreground">{t('landing.pricingDesc')}</p>
          </div>
          <p className="rounded-full border border-primary/20 bg-primary/[0.08] px-3 py-1.5 text-xs font-medium text-primary">
            {pricingRegion === 'overseas' ? t('landing.pricingRegionOverseas') : t('landing.pricingRegionMainland')}
          </p>
        </div>
        <div
          className={cn(
            'grid gap-4',
            pricingRegion === 'overseas' ? 'lg:grid-cols-2 xl:grid-cols-4' : 'lg:grid-cols-3',
          )}
        >
          {visiblePricingPlans.map((plan) => {
            const isFree = 'isFree' in plan && plan.isFree;
            const planName =
              isFree && 'nameKey' in plan ? t(plan.nameKey) : 'name' in plan ? plan.name : '';
            const uploadParams = 'uploadGib' in plan ? { gib: plan.uploadGib } : undefined;

            return (
              <article
                key={plan.id}
                className={cn(
                  'landing-glass-card relative flex flex-col rounded-3xl p-6',
                  plan.popular && 'border-primary/40 bg-primary/[0.04] shadow-primary/10',
                )}
              >
              {plan.popular && (
                <span className="absolute right-4 top-4 rounded-full bg-primary px-2.5 py-1 text-[11px] font-semibold text-primary-foreground">
                  {t('landing.pricingPopular')}
                </span>
              )}
              <div>
                <p className="text-lg font-semibold tracking-tight">{planName}</p>
                <div className="mt-5">
                  <span className="font-display text-4xl font-bold tracking-tight">
                    {isFree && 'priceKey' in plan ? t(plan.priceKey) : 'price' in plan ? plan.price : ''}
                  </span>
                  {!isFree && 'suffixKey' in plan && (
                    <span className="ml-1 text-sm text-muted-foreground">{t(plan.suffixKey)}</span>
                  )}
                </div>
                <p className="mt-1 text-xs text-muted-foreground">{t(plan.secondaryKey)}</p>
              </div>
              <ul className="mt-6 flex-1 space-y-3 text-sm text-muted-foreground">
                <li className="flex gap-2">
                  <span className="text-primary">✓</span>
                  <span>{t('landing.pricingFeatureDevices', { count: plan.devices })}</span>
                </li>
                {plan.featureKeys.map((key) => (
                  <li key={key} className="flex gap-2">
                    <span className="text-primary">✓</span>
                    <span>{t(key, uploadParams)}</span>
                  </li>
                ))}
              </ul>
              <Link
                href={isFree ? webTrialHref : purchaseHref}
                className={cn(
                  buttonVariants({ variant: isFree ? 'outline' : 'default' }),
                  'mt-6 h-11 rounded-2xl font-semibold',
                )}
              >
                {t(isFree ? 'landing.pricingFreeCta' : 'landing.pricingCta')}
              </Link>
            </article>
            );
          })}
        </div>
      </section>

      <section className="relative z-10 mx-auto w-full max-w-4xl px-5 pb-20 md:px-8" id="faq">
        <div className="mb-8 text-center">
          <p className="font-mono text-xs uppercase tracking-[0.3em] text-primary/80">{t('landing.faqKicker')}</p>
          <h2 className="font-display mt-3 text-3xl font-semibold tracking-tight">{t('landing.faqTitle')}</h2>
        </div>
        <div className="space-y-3">
          {faqItems.map((item) => (
            <article key={item.q} className="landing-glass-card rounded-2xl px-5 py-4">
              <h3 className="text-sm font-semibold">{t(item.q)}</h3>
              <p className="mt-3 text-sm leading-7 text-muted-foreground">{t(item.a)}</p>
            </article>
          ))}
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
