import { getApiUrl } from '@/lib/config';

/** 国内分发：123 云盘分享页 */
export const CLIENT_RELEASE_URL_MAINLAND =
  'https://1816849228.share.123pan.cn/123pan/cXByVv-Z76m';

/** 出海分发：Google Drive 分享文件夹 */
export const CLIENT_RELEASE_URL_OVERSEAS =
  'https://drive.google.com/drive/folders/1_BL255lRlZkXGcO447htvtpHItpzJGaA?usp=drive_link';

export type WebDeploymentRegionHint = {
  /** 请求 Host（SSR 从 headers 传入） */
  host?: string | null;
  /** 站点 origin（SSR 从 getSiteOriginFromHost 传入，如 https://shrimpsend.com） */
  siteOrigin?: string | null;
};

function hostLooksOverseas(host: string): boolean {
  const h = host.toLowerCase();
  return h.includes('shrimpsend');
}

function openPanelWebCluster(): 'intl' | 'cn' | null {
  const cluster = process.env.NEXT_PUBLIC_OPENPANEL_WEB_CLUSTER?.trim().toLowerCase();
  if (cluster === 'intl') return 'intl';
  if (cluster === 'cn') return 'cn';
  return null;
}

/**
 * 判断当前 Web 部署是否为出海集群（与 openpanelClient 公网规则对齐）。
 * SSR/SSG 请传入 host 或 siteOrigin，避免 getApiUrl() 在服务端恒为 localhost 误判为国内。
 */
export function isClientDownloadOverseas(hint?: WebDeploymentRegionHint): boolean {
  const cluster = openPanelWebCluster();
  if (cluster === 'intl') return true;
  if (cluster === 'cn') return false;

  if (hint?.host && hostLooksOverseas(hint.host)) return true;

  if (hint?.siteOrigin) {
    try {
      if (hostLooksOverseas(new URL(hint.siteOrigin).hostname)) return true;
    } catch {
      if (hint.siteOrigin.toLowerCase().includes('shrimpsend')) return true;
    }
  }

  if (typeof window !== 'undefined' && hostLooksOverseas(window.location.hostname)) {
    return true;
  }

  try {
    if (getApiUrl().toLowerCase().includes('shrimpsend.com')) return true;
  } catch {
    /* ignore */
  }

  return false;
}

export function getClientReleaseDownloadUrl(hint?: WebDeploymentRegionHint): string {
  return isClientDownloadOverseas(hint) ? CLIENT_RELEASE_URL_OVERSEAS : CLIENT_RELEASE_URL_MAINLAND;
}

export function openClientReleaseDownload(hint?: WebDeploymentRegionHint): void {
  window.open(getClientReleaseDownloadUrl(hint), '_blank', 'noopener,noreferrer');
}
