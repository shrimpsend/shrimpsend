'use client';

import { useMemo } from 'react';
import { useChatContext, S3_VIRTUAL_DEVICE_ID } from '@/contexts/ChatContext';
import { useI18n } from '@/contexts/I18nContext';
import { buildTransferModeOptions } from '@/lib/sendModeResolution';
import { cn } from '@/lib/utils';
import { isWebPeer } from '@/lib/peerPlatform';
import type { WebSendMode } from '@/lib/sendTargetStorage';
import { RefreshCw } from 'lucide-react';
import { Button } from '@/components/ui/button';

export function TransferModeBar() {
  const { t } = useI18n();
  const {
    sendMode,
    onSendModeChange,
    webrtcAvailable,
    selectedDeviceId,
    devices,
    deviceReach,
    runSessionConnectionDiagnostic,
    checkS3Config,
    s3Configured,
    s3Online,
  } = useChatContext();

  const hidden =
    !selectedDeviceId || selectedDeviceId === S3_VIRTUAL_DEVICE_ID;

  const selectedDevice = selectedDeviceId
    ? devices.find((d) => d.deviceId === selectedDeviceId)
    : undefined;
  const peerIsWeb = isWebPeer(selectedDevice?.platform);

  const entry = selectedDeviceId ? deviceReach[selectedDeviceId] : undefined;
  const sessionProbing = entry?.probing ?? false;
  const methods = entry?.methods;
  const httpAvailable = !!(
    methods?.directHttp ||
    methods?.pullReachable ||
    methods?.peerHttpHealthy ||
    methods?.lanSignaling
  );
  const httpPullOnly = !!(methods?.pullReachable && !methods?.directHttp);
  const s3Available = s3Configured && s3Online;

  const allModes: { value: WebSendMode; label: string; available: boolean; attemptable: boolean }[] = useMemo(() => {
    if (hidden) return [];
    const options = buildTransferModeOptions({
      peerIsWeb,
      webrtcAvailable,
      httpAvailable,
      webrtcReachable: !!methods?.webrtc,
      s3Available,
    });
    const labelFor = (value: WebSendMode): string => {
      switch (value) {
        case 'lan':
          return t('chat.transportMode.httpLan');
        case 'webrtc':
          return peerIsWeb
            ? t('chat.transferBar.webrtc')
            : t('chat.transportMode.webrtcLan');
        case 's3':
          return t('chat.transferBar.s3');
      }
    };
    return options.map((m) => ({
      value: m.value,
      label: labelFor(m.value),
      available: m.available,
      attemptable: m.attemptable,
    }));
  }, [
    hidden,
    peerIsWeb,
    webrtcAvailable,
    methods?.webrtc,
    httpAvailable,
    s3Available,
    t,
  ]);

  if (hidden || allModes.length === 0) return null;

  const sorted = [...allModes].sort((a, b) => {
    if (a.available === b.available) return 0;
    return a.available ? -1 : 1;
  });

  return (
    <div className="flex shrink-0 items-center gap-1 border-b border-border/50 bg-card px-3 py-1.5">
      <span className="text-[11px] text-muted-foreground mr-1 shrink-0">{t('chat.transportMode.label')}</span>
      <div className="flex items-center gap-0.5 flex-1 min-w-0 flex-wrap">
        {sorted.map((m) => (
          <button
            key={m.value}
            type="button"
            onClick={() => m.attemptable && onSendModeChange(m.value)}
            disabled={!m.attemptable}
            className={cn(
              'inline-flex items-center gap-1 rounded-md px-2 py-1 text-[11px] font-medium transition-colors',
              sendMode === m.value
                ? 'item-selected-soft text-primary'
                : m.attemptable
                  ? 'bg-muted/60 text-foreground hover:bg-muted cursor-pointer'
                  : 'bg-muted/30 text-text-tertiary cursor-not-allowed opacity-60',
            )}
          >
            {m.label}
            <span
              className={cn(
                'size-1.5 shrink-0 rounded-full',
                m.available
                  ? (m.value === 'lan' && httpPullOnly ? 'bg-sky-500' : 'bg-emerald-500')
                  : m.attemptable && m.value === 'lan'
                    ? 'bg-amber-500'
                    : 'bg-text-tertiary/60',
              )}
            />
          </button>
        ))}
      </div>
      <Button
        type="button"
        variant="ghost"
        size="icon-sm"
        className="shrink-0"
        title={t('deviceList.refreshReachTitle')}
        disabled={sessionProbing}
        onClick={() => {
          if (selectedDeviceId && selectedDeviceId !== S3_VIRTUAL_DEVICE_ID) {
            runSessionConnectionDiagnostic(selectedDeviceId);
          } else {
            void checkS3Config();
          }
        }}
      >
        <RefreshCw className={cn('size-3.5', sessionProbing && 'motion-safe:animate-spin')} />
      </Button>
    </div>
  );
}
