import type { WebSendMode } from '@/lib/sendTargetStorage';

export type TransferModeDotState =
  | 'verified'
  | 'pullOnly'
  | 'attemptable'
  | 'unchecked'
  | 'unavailable';

export type TransferModeBarItem = {
  value: WebSendMode;
  label: string;
  available: boolean;
  attemptable: boolean;
  reachKnownOnline: boolean | null;
  reachPullOnly: boolean;
};

export function resolveTransferModeDotState(input: {
  mode: WebSendMode;
  reachKnownOnline: boolean | null;
  reachPullOnly: boolean;
  attemptable: boolean;
}): TransferModeDotState {
  if (input.mode === 'webrtc' && input.reachKnownOnline === null) {
    return 'unchecked';
  }
  if (input.reachKnownOnline === true) {
    return input.reachPullOnly ? 'pullOnly' : 'verified';
  }
  if (input.attemptable && input.mode === 'lan') {
    return 'attemptable';
  }
  return 'unavailable';
}

export function resolveTransferModeDotStateFromItem(
  item: TransferModeBarItem,
): TransferModeDotState {
  return resolveTransferModeDotState({
    mode: item.value,
    reachKnownOnline: item.reachKnownOnline,
    reachPullOnly: item.reachPullOnly,
    attemptable: item.attemptable,
  });
}

export function transferModeDotClassName(state: TransferModeDotState): string {
  switch (state) {
    case 'verified':
      return 'bg-emerald-500';
    case 'pullOnly':
      return 'bg-sky-500';
    case 'attemptable':
      return 'bg-amber-500';
    case 'unchecked':
      return 'bg-primary';
    case 'unavailable':
      return 'bg-text-tertiary/60';
  }
}

type TranslateFn = (key: string) => string;

export function transferModeDotTooltip(
  t: TranslateFn,
  item: TransferModeBarItem,
  s3Configured: boolean,
): string {
  const state = resolveTransferModeDotStateFromItem(item);
  switch (item.value) {
    case 'lan':
      switch (state) {
        case 'verified':
          return t('chat.transportModeDot.httpVerified');
        case 'pullOnly':
          return t('chat.transportModeDot.httpPullOnly');
        case 'attemptable':
          return t('chat.transportModeDot.httpAttemptable');
        default:
          return t('chat.transportModeDot.unavailable');
      }
    case 'webrtc':
      switch (state) {
        case 'verified':
          return t('chat.transportModeDot.webrtcVerified');
        case 'unchecked':
          return t('chat.transportModeDot.webrtcUnchecked');
        default:
          return t('chat.transportModeDot.webrtcUnavailable');
      }
    case 's3':
      if (state === 'verified') {
        return t('chat.connectionDiag.reasonS3Online');
      }
      return s3Configured
        ? t('chat.connectionDiag.reasonS3Unavailable')
        : t('chat.connectionDiag.reasonS3NotConfigured');
    default:
      return t('chat.transportModeDot.unavailable');
  }
}

export const LEGEND_STATES: TransferModeDotState[] = [
  'verified',
  'pullOnly',
  'attemptable',
  'unchecked',
  'unavailable',
];

export function transferModeDotLegendLabel(
  t: TranslateFn,
  state: TransferModeDotState,
): string {
  switch (state) {
    case 'verified':
      return t('chat.transportModeDot.legendVerified');
    case 'pullOnly':
      return t('chat.transportModeDot.legendPullOnly');
    case 'attemptable':
      return t('chat.transportModeDot.legendAttemptable');
    case 'unchecked':
      return t('chat.transportModeDot.legendUnchecked');
    case 'unavailable':
      return t('chat.transportModeDot.legendUnavailable');
  }
}
