import type { DeviceDto } from '@/lib/api';
import { buildTransferModeOptions } from '@/lib/sendModeResolution';
import type { ProbePriority } from '@/lib/probePriority';
import type { DeviceReachDetail } from '@/hooks/useSendTargetProbes';
import type { TranslateFn } from '@/contexts/I18nContext';
import { isWebPeer } from '@/lib/peerPlatform';

export type DiagnosticStepId =
  | 'httpDirect'
  | 'httpSignaling'
  | 'httpPull'
  | 'webrtc'
  | 's3';

export type DiagnosticStepStatus = 'pending' | 'running' | 'success' | 'failure';

export type DiagnosticStep = {
  id: DiagnosticStepId;
  title: string;
  status: DiagnosticStepStatus;
  elapsedMs?: number;
  reason?: string;
  startedAt?: number;
};

export type ConnectionDiagnosticState = {
  peerId: string;
  peerLabel: string;
  steps: DiagnosticStep[];
  running: boolean;
  summary?: string;
};

export function diagnosticStepOrder(devicePriority: ProbePriority): DiagnosticStepId[] {
  const lan: DiagnosticStepId[] = ['httpDirect'];
  const cloud: DiagnosticStepId[] = ['httpSignaling', 'httpPull', 'webrtc'];
  const fallback: DiagnosticStepId[] = ['s3'];

  const core =
    devicePriority === 'lanDiscovered'
      ? [...lan, ...cloud]
      : [...cloud, ...lan];
  return [...core, ...fallback];
}

export function diagnosticStepTitle(t: TranslateFn, id: DiagnosticStepId): string {
  switch (id) {
    case 'httpDirect':
      return t('chat.connectionDiag.stepHttpDirect');
    case 'httpSignaling':
      return t('chat.connectionDiag.stepHttpSignaling');
    case 'httpPull':
      return t('chat.connectionDiag.stepHttpPull');
    case 'webrtc':
      return t('chat.connectionDiag.stepWebrtc');
    case 's3':
      return t('chat.connectionDiag.stepS3');
  }
}

export function diagnosticStepHelp(
  t: TranslateFn,
  id: DiagnosticStepId,
): { title: string; body: string } {
  switch (id) {
    case 'httpDirect':
      return {
        title: t('chat.connectionDiag.helpHttpDirectTitle'),
        body: t('chat.connectionDiag.helpHttpDirectBody'),
      };
    case 'httpSignaling':
      return {
        title: t('chat.connectionDiag.helpHttpSignalingTitle'),
        body: t('chat.connectionDiag.helpHttpSignalingBody'),
      };
    case 'httpPull':
      return {
        title: t('chat.connectionDiag.helpHttpPullTitle'),
        body: t('chat.connectionDiag.helpHttpPullBody'),
      };
    case 'webrtc':
      return {
        title: t('chat.connectionDiag.helpWebrtcTitle'),
        body: t('chat.connectionDiag.helpWebrtcBody'),
      };
    case 's3':
      return {
        title: t('chat.connectionDiag.helpS3Title'),
        body: t('chat.connectionDiag.helpS3Body'),
      };
  }
}

export function formatDiagnosticElapsed(ms: number): string {
  if (ms < 1000) return `${ms}ms`;
  return `${(ms / 1000).toFixed(1)}s`;
}

export function buildDiagnosticSummary(
  t: TranslateFn,
  methods: DeviceReachDetail,
  input: {
    peerIsWeb: boolean;
    webrtcAvailable: boolean;
    s3Available: boolean;
  },
): string {
  const httpAvailable = !!(
    methods.directHttp ||
    methods.pullReachable ||
    methods.peerHttpHealthy
  );
  const options = buildTransferModeOptions({
    peerIsWeb: input.peerIsWeb,
    webrtcAvailable: input.webrtcAvailable,
    httpAvailable,
    webrtcReachable: methods.webrtc,
    s3Available: input.s3Available,
  });
  const best = options.find((o) => o.available);
  if (!best) return t('chat.connectionDiag.summaryNoRoute');

  const modeLabel =
    best.value === 'lan'
      ? t('chat.transportMode.httpLan')
      : best.value === 'webrtc'
        ? t('chat.transportMode.webrtcLan')
        : t('chat.transferBar.s3');

  const reason =
    best.value === 'lan'
      ? methods.directHttp
        ? t('chat.connectionDiag.reasonHttpDirectOk')
        : t('chat.connectionDiag.reasonHttpPullOk')
      : best.value === 'webrtc'
        ? t('chat.connectionDiag.reasonWebrtcOnline')
        : t('chat.connectionDiag.reasonS3Online');

  return t('chat.connectionDiag.summaryRecommend', { mode: modeLabel, reason });
}

function trimLanUrl(url?: string | null): string | undefined {
  const trimmed = url?.trim();
  return trimmed && trimmed.length > 0 ? trimmed : undefined;
}

/** Merge LAN URL from device DTO, prior probe cache, and in-run signaling discovery. */
export function resolvePeerLanHttpUrl(
  device: DeviceDto,
  sources: { initialFreshLanUrl?: string; discoveredLanUrl?: string },
): string | undefined {
  return (
    trimLanUrl(device.lanHttpUrl) ??
    trimLanUrl(sources.initialFreshLanUrl) ??
    trimLanUrl(sources.discoveredLanUrl)
  );
}

export type ConnectionDiagnosticProbeDeps = {
  device: DeviceDto;
  orderedStepIds: DiagnosticStepId[];
  initialFreshLanUrl?: string;
  connected: boolean;
  isLoggedIn: boolean;
  webrtcAvailable: boolean;
  onDirectHttpProbe: (url: string) => Promise<boolean>;
  onLanHttpProbe: (
    deviceId: string,
  ) => Promise<{ success: boolean; lanHttpUrl?: string; senderReachable?: boolean }>;
  onPullProbe: (deviceId: string) => Promise<boolean>;
  onWebRTCProbe: (deviceId: string) => Promise<boolean>;
  onCheckS3: () => Promise<{ configured: boolean; online: boolean }>;
  t: TranslateFn;
  onStepUpdate: (steps: DiagnosticStep[]) => void;
  isCancelled: () => boolean;
};

export async function runConnectionDiagnostic(
  deps: ConnectionDiagnosticProbeDeps,
): Promise<{ methods: DeviceReachDetail; freshLanUrl?: string }> {
  const { device, orderedStepIds, t, onStepUpdate, isCancelled } = deps;

  let steps: DiagnosticStep[] = orderedStepIds.map((id) => ({
    id,
    title: diagnosticStepTitle(t, id),
    status: 'pending',
  }));

  const patchStep = (id: DiagnosticStepId, patch: Partial<DiagnosticStep>) => {
    steps = steps.map((s) => (s.id === id ? { ...s, ...patch } : s));
    onStepUpdate(steps);
  };

  const beginStep = (id: DiagnosticStepId) => {
    patchStep(id, {
      status: 'running',
      startedAt: Date.now(),
      elapsedMs: undefined,
      reason: undefined,
    });
  };

  const finishStep = (
    id: DiagnosticStepId,
    status: 'success' | 'failure',
    reason: string,
    startedAt?: number,
  ) => {
    const end = Date.now();
    patchStep(id, {
      status,
      reason,
      elapsedMs: startedAt != null ? end - startedAt : undefined,
    });
  };

  let directHttp = false;
  let peerHttpHealthy = false;
  let pullReachable = false;
  let webrtcResult = false;
  let freshLanUrl: string | undefined;
  let discoveredLanUrl: string | undefined;
  let httpDirectFailedNoUrl = false;

  const probeHttpDirect = async (lanUrl: string): Promise<boolean> => {
    try {
      return await deps.onDirectHttpProbe(lanUrl);
    } catch {
      return false;
    }
  };

  const finishHttpDirectWithUrl = (ok: boolean, lanUrl: string, startedAt: number) => {
    directHttp = ok;
    finishStep(
      'httpDirect',
      ok ? 'success' : 'failure',
      ok
        ? t('chat.connectionDiag.reasonHttpDirectOk')
        : t('chat.connectionDiag.reasonHttpDirectFail'),
      startedAt,
    );
    if (ok) freshLanUrl = lanUrl;
  };

  const backfillHttpDirect = async (lanUrl: string) => {
    if (isCancelled()) return;
    const startedAt = Date.now();
    patchStep('httpDirect', {
      status: 'running',
      startedAt,
      elapsedMs: undefined,
      reason: undefined,
    });
    const ok = await probeHttpDirect(lanUrl);
    finishHttpDirectWithUrl(ok, lanUrl, startedAt);
    httpDirectFailedNoUrl = false;
  };

  for (const stepId of orderedStepIds) {
    if (isCancelled()) break;
    beginStep(stepId);
    const startedAt = Date.now();

    switch (stepId) {
      case 'httpDirect': {
        const lanUrl = resolvePeerLanHttpUrl(device, {
          initialFreshLanUrl: deps.initialFreshLanUrl,
          discoveredLanUrl,
        });
        if (!lanUrl) {
          httpDirectFailedNoUrl = true;
          finishStep(stepId, 'failure', t('chat.connectionDiag.reasonHttpDirectNoUrl'), startedAt);
        } else {
          const ok = await probeHttpDirect(lanUrl);
          finishHttpDirectWithUrl(ok, lanUrl, startedAt);
        }
        break;
      }
      case 'httpSignaling': {
        if (!deps.connected) {
          finishStep(stepId, 'failure', t('chat.connectionDiag.reasonOfflineCloud'), startedAt);
        } else {
          try {
            const r = await deps.onLanHttpProbe(device.deviceId);
            peerHttpHealthy = r.success;
            if (r.senderReachable) pullReachable = true;
            const signalUrl = trimLanUrl(r.lanHttpUrl);
            if (signalUrl) {
              discoveredLanUrl = signalUrl;
              freshLanUrl = signalUrl;
            }
            finishStep(
              stepId,
              peerHttpHealthy ? 'success' : 'failure',
              peerHttpHealthy
                ? t('chat.connectionDiag.reasonHttpSignalingOk')
                : t('chat.connectionDiag.reasonHttpSignalingFail'),
              startedAt,
            );
            if (httpDirectFailedNoUrl && signalUrl) {
              await backfillHttpDirect(signalUrl);
            }
          } catch {
            finishStep(stepId, 'failure', t('chat.connectionDiag.reasonHttpSignalingFail'), startedAt);
          }
        }
        break;
      }
      case 'httpPull': {
        if (!deps.connected) {
          finishStep(stepId, 'failure', t('chat.connectionDiag.reasonOfflineCloud'), startedAt);
        } else {
          try {
            const ok = await deps.onPullProbe(device.deviceId);
            if (ok) pullReachable = true;
            finishStep(
              stepId,
              ok ? 'success' : 'failure',
              ok
                ? t('chat.connectionDiag.reasonHttpPullOk')
                : t('chat.connectionDiag.reasonHttpPullFail'),
              startedAt,
            );
          } catch {
            finishStep(stepId, 'failure', t('chat.connectionDiag.reasonHttpPullFail'), startedAt);
          }
        }
        break;
      }
      case 'webrtc': {
        if (!deps.connected) {
          finishStep(stepId, 'failure', t('chat.connectionDiag.reasonOfflineCloud'), startedAt);
        } else if (!deps.webrtcAvailable) {
          finishStep(stepId, 'failure', t('chat.connectionDiag.reasonWebrtcFail'), startedAt);
        } else {
          try {
            webrtcResult = await deps.onWebRTCProbe(device.deviceId);
            finishStep(
              stepId,
              webrtcResult ? 'success' : 'failure',
              webrtcResult
                ? t('chat.connectionDiag.reasonWebrtcOnline')
                : t('chat.connectionDiag.reasonWebrtcFail'),
              startedAt,
            );
          } catch {
            webrtcResult = false;
            finishStep(stepId, 'failure', t('chat.connectionDiag.reasonWebrtcFail'), startedAt);
          }
        }
        break;
      }
      case 's3': {
        if (!deps.isLoggedIn) {
          finishStep(stepId, 'failure', t('chat.connectionDiag.reasonS3LoginRequired'), startedAt);
        } else {
          try {
            const { configured, online } = await deps.onCheckS3();
            if (!configured) {
              finishStep(stepId, 'failure', t('chat.connectionDiag.reasonS3NotConfigured'), startedAt);
            } else if (online) {
              finishStep(stepId, 'success', t('chat.connectionDiag.reasonS3Online'), startedAt);
            } else {
              finishStep(stepId, 'failure', t('chat.connectionDiag.reasonS3Unavailable'), startedAt);
            }
          } catch {
            finishStep(stepId, 'failure', t('chat.connectionDiag.reasonS3Unavailable'), startedAt);
          }
        }
        break;
      }
    }
  }

  return {
    methods: {
      directHttp,
      peerHttpHealthy,
      pullReachable,
      webrtc: webrtcResult,
      lanSignaling: peerHttpHealthy,
    },
    freshLanUrl,
  };
}

export function peerLabelForDevice(device: DeviceDto): string {
  const name = device.name?.trim();
  if (name) return name;
  return device.deviceId.length > 12
    ? `${device.deviceId.slice(0, 12)}…`
    : device.deviceId;
}

export function isPeerWebDevice(device?: DeviceDto): boolean {
  return isWebPeer(device?.platform);
}
