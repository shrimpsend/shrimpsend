import type { WebSendMode } from '@/lib/sendTargetStorage';

export type TransferModeOption = {
  value: WebSendMode;
  available: boolean;
  /** User may select and try even when [available] is false. */
  attemptable: boolean;
};

export function buildTransferModeOptions(input: {
  peerIsWeb: boolean;
  webrtcAvailable: boolean;
  httpAvailable: boolean;
  webrtcReachable: boolean | null;
  s3Available: boolean;
}): TransferModeOption[] {
  const modes: TransferModeOption[] = [];
  if (input.peerIsWeb) {
    if (input.webrtcAvailable) {
      modes.push({ value: 'webrtc', available: input.webrtcReachable === true, attemptable: true });
    }
    modes.push({ value: 's3', available: input.s3Available, attemptable: input.s3Available });
  } else {
    modes.push({
      value: 'lan',
      available: input.httpAvailable,
      attemptable: true,
    });
    if (input.webrtcAvailable) {
      modes.push({ value: 'webrtc', available: input.webrtcReachable === true, attemptable: true });
    }
    modes.push({ value: 's3', available: input.s3Available, attemptable: input.s3Available });
  }
  return modes;
}

/** Keep [preferred] when still available; otherwise pick the first online mode. */
export function resolveSendModeWithMemory(
  preferred: WebSendMode,
  modes: TransferModeOption[],
): WebSendMode {
  if (modes.length === 0) return preferred;

  const visible = new Set(modes.map((m) => m.value));
  if (!visible.has(preferred)) {
    const hit = modes.find((m) => m.available);
    return hit?.value ?? modes[0]!.value;
  }

  const preferredEntry = modes.find((m) => m.value === preferred);
  if (preferredEntry?.available) return preferred;

  const fallback = modes.find((m) => m.available);
  return fallback?.value ?? preferred;
}

/** Session auto mode: direct-first priority (HTTP → WebRTC → S3). */
export function resolveSendModeAutoPreferHttp(
  modes: TransferModeOption[],
  fallback: WebSendMode = 'lan',
): WebSendMode {
  if (modes.length === 0) return fallback;

  const order: WebSendMode[] = ['lan', 'webrtc', 's3'];
  for (const value of order) {
    const entry = modes.find((m) => m.value === value);
    if (entry?.available) return value;
  }

  const hit = modes.find((m) => m.available);
  return hit?.value ?? modes[0]!.value;
}
