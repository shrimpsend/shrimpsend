'use client';

import Image from 'next/image';
import { useI18n } from '@/contexts/I18nContext';
import {
  LANDING_HERO_SHOWCASE_HEIGHT,
  LANDING_HERO_SHOWCASE_SRC,
  LANDING_HERO_SHOWCASE_WIDTH,
} from '@/lib/landingAssets';

export function LandingShowcaseImage() {
  const { t } = useI18n();

  return (
    <section className="relative z-10 mx-auto w-full max-w-7xl px-5 pb-12 md:px-8 lg:pb-16">
      <div className="overflow-hidden rounded-3xl border border-white/10 bg-white/[0.04] shadow-2xl shadow-black/25 ring-1 ring-white/[0.06]">
        <Image
          src={LANDING_HERO_SHOWCASE_SRC}
          alt={t('landing.showcaseAlt')}
          width={LANDING_HERO_SHOWCASE_WIDTH}
          height={LANDING_HERO_SHOWCASE_HEIGHT}
          priority
          sizes="(max-width: 1280px) 100vw, 1280px"
          className="h-auto w-full"
        />
      </div>
    </section>
  );
}
