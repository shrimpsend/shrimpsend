'use client';

import { useMemo } from 'react';
import { BrandLogo } from '@/components/brand/BrandLogo';
import { useI18n } from '@/contexts/I18nContext';
import { collatorForLocaleTag } from '@/lib/i18nCollator';
import { useChatContext, S3_VIRTUAL_DEVICE_ID } from '@/contexts/ChatContext';
import { DeviceConversationItem } from '@/components/devices/DeviceConversationItem';
import { getReachDisplayStatus, isReachOnline, reachSortPriority } from '@/hooks/useSendTargetProbes';
import { Button } from '@/components/ui/button';
import { formatDisplayCodeChipLabel } from '@/lib/displayCode';
import { localizedDocsHref, localeTagToPath } from '@/lib/i18nRouting';
import { openInNewTab } from '@/lib/openInNewTab';
import { cn } from '@/lib/utils';
import { getDeviceName } from '@/lib/deviceId';
import { BookOpen, Cloud, Download, RefreshCw, Settings } from 'lucide-react';

export function DeviceListPanel({
  onShowSettings,
  onShowDownload,
  className,
}: {
  onShowSettings: () => void;
  onShowDownload: () => void;
  className?: string;
}) {
  const { t, localeTag } = useI18n();
  const docsHref = localizedDocsHref(localeTagToPath(localeTag), 'intro');
  const nameCollator = useMemo(() => collatorForLocaleTag(localeTag), [localeTag]);
  const {
    connected,
    devices,
    currentDeviceId,
    otherDevices,
    selectedDeviceId,
    setSelectedDeviceId,
    deviceReach,
    targetsProbing,
    refreshSendTargets,
    messages,
    s3Configured,
    s3Online,
    s3Checking,
  } = useChatContext();

  const registeredIds = useMemo(
    () => new Set(devices.map((d) => d.deviceId)),
    [devices],
  );

  const selfDisplayCode = useMemo(
    () => devices.find((d) => d.deviceId === currentDeviceId)?.displayCode ?? null,
    [devices, currentDeviceId],
  );

  const deviceLastMessages = useMemo(() => {
    const map: Record<string, string> = {};
    for (let i = messages.length - 1; i >= 0; i--) {
      const msg = messages[i];
      if (!msg) continue;
      const deviceId = msg.fromDeviceId;
      if (map[deviceId]) continue;
      if (msg.type === 'text') {
        const text = (msg.payload as { text?: string })?.text;
        if (text) map[deviceId] = text;
      } else if (msg.type === 'file') {
        const fileName = (msg.payload as { fileName?: string })?.fileName;
        if (fileName) map[deviceId] = t('deviceList.fileLine', { fileName });
      }
    }
    return map;
  }, [messages, t]);

  const sortedDevices = useMemo(() => {
    return [...otherDevices].sort((a, b) => {
      const aMine = registeredIds.has(a.deviceId);
      const bMine = registeredIds.has(b.deviceId);
      if (aMine !== bMine) return aMine ? -1 : 1;
      const byReach =
        reachSortPriority(deviceReach[a.deviceId]) -
        reachSortPriority(deviceReach[b.deviceId]);
      if (byReach !== 0) return byReach;
      return nameCollator.compare(a.name, b.name);
    });
  }, [otherDevices, deviceReach, registeredIds, nameCollator]);

  return (
    <div className={cn('flex h-full flex-col bg-background', className)}>
      {/* Header */}
      <div className="flex shrink-0 items-center justify-between gap-2 border-b border-border/60 bg-background px-3 py-3">
        <div className="flex items-center gap-2.5 min-w-0">
          <BrandLogo
            size={28}
            alt={t('deviceList.logoAlt')}
            className="shrink-0 shadow-sm ring-1 ring-foreground/6"
            priority
          />
          <div className="flex min-w-0 flex-col">
            <div className="flex items-baseline gap-x-1.5">
              <span className="font-display shrink-0 text-base font-semibold tracking-tight">{t('deviceList.brand')}</span>
              <span className={cn(
                'text-[10px] font-medium leading-none shrink-0',
                connected ? 'text-emerald-500' : 'text-amber-500',
              )}>
                {connected ? t('deviceList.online') : t('deviceList.connecting')}
              </span>
            </div>
            <div className="flex min-w-0 flex-nowrap items-center gap-1">
              {selfDisplayCode != null && (
                <span
                  title={`${t('chat.header.deviceNumber')} ${selfDisplayCode}`}
                  className="shrink-0 rounded-md border border-border/70 bg-muted/50 px-1.5 py-0 font-mono text-[10px] font-semibold tabular-nums leading-tight text-muted-foreground"
                >
                  {formatDisplayCodeChipLabel(selfDisplayCode)}
                </span>
              )}
              <span className="min-w-0 flex-1 truncate text-[11px] text-muted-foreground">{getDeviceName()}</span>
            </div>
          </div>
        </div>
        <div className="flex items-center gap-0.5 shrink-0">
          <Button variant="ghost" size="icon-sm" onClick={onShowDownload} title={t('deviceList.downloadTitle')}>
            <Download className="size-4" />
          </Button>
          <Button
            variant="ghost"
            size="icon-sm"
            onClick={() => openInNewTab(docsHref)}
            title={t('deviceList.docsTitle')}
          >
            <BookOpen className="size-4" />
          </Button>
          <Button variant="ghost" size="icon-sm" onClick={onShowSettings} title={t('deviceList.settingsTitle')}>
            <Settings className="size-4" />
          </Button>
        </div>
      </div>

      {/* Device list */}
      <div className="flex-1 min-h-0 overflow-y-auto">
        {sortedDevices.length === 0 && !s3Configured ? (
          <div className="flex flex-col items-center justify-center gap-3 px-6 py-12 text-center text-muted-foreground">
            <p className="text-sm">{t('deviceList.emptyTitle')}</p>
            <p className="text-xs text-muted-foreground/70">
              {t('deviceList.emptyHint')}
            </p>
          </div>
        ) : (
          <div className="space-y-1 px-1 py-1">
            {/* S3 virtual device — pinned to top */}
            {s3Configured && (
              <button
                type="button"
                onClick={() => setSelectedDeviceId(S3_VIRTUAL_DEVICE_ID)}
                className={cn(
                  'flex w-full items-center gap-3 rounded-lg px-2.5 py-3 text-left transition-colors duration-150',
                  selectedDeviceId === S3_VIRTUAL_DEVICE_ID
                    ? 'item-selected-soft'
                    : 'bg-card hover:bg-muted/60',
                )}
              >
                <div className="relative shrink-0">
                  <div
                    className={cn(
                      'flex size-10 items-center justify-center rounded-lg transition-colors',
                      selectedDeviceId === S3_VIRTUAL_DEVICE_ID
                        ? 'bg-primary/12'
                        : 'bg-sky-500/10',
                    )}
                  >
                    <Cloud
                      className={cn(
                        'size-[22px]',
                        selectedDeviceId === S3_VIRTUAL_DEVICE_ID
                          ? 'text-primary'
                          : 'text-sky-500',
                      )}
                    />
                  </div>
                  <span
                    className={cn(
                      'absolute -bottom-0.5 -right-0.5 size-3 rounded-full border-2 border-card',
                      s3Checking
                        ? 'bg-amber-400'
                        : !s3Configured
                          ? 'bg-muted-foreground/40'
                          : s3Online
                            ? 'bg-emerald-500'
                            : 'bg-amber-400',
                    )}
                  />
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-baseline justify-between gap-2">
                    <span className={cn(
                      'truncate text-sm',
                      selectedDeviceId === S3_VIRTUAL_DEVICE_ID
                        ? 'font-semibold text-primary'
                        : 'font-medium text-foreground',
                    )}>
                      {t('deviceList.s3RelayTitle')}
                    </span>
                  </div>
                  <p
                    className={cn(
                      'mt-0.5 text-xs',
                      selectedDeviceId === S3_VIRTUAL_DEVICE_ID
                        ? 'text-muted-foreground'
                        : 'text-text-tertiary',
                    )}
                  >
                    {s3Checking
                      ? t('deviceList.s3Checking')
                      : !s3Configured
                        ? t('deviceList.s3NotConfigured')
                        : s3Online
                          ? t('deviceList.s3OnlineAll')
                          : t('deviceList.s3Unavailable')}
                  </p>
                </div>
              </button>
            )}
            {sortedDevices.map((device) => (
              <DeviceConversationItem
                key={device.deviceId}
                device={device}
                isMyDevice={registeredIds.has(device.deviceId)}
                selected={selectedDeviceId === device.deviceId}
                reachStatus={getReachDisplayStatus(deviceReach[device.deviceId])}
                lastMessage={deviceLastMessages[device.deviceId]}
                onClick={() => setSelectedDeviceId(device.deviceId)}
              />
            ))}
          </div>
        )}
      </div>

      {/* Bottom bar with refresh */}
      <div className="flex shrink-0 items-center justify-between gap-2 border-t border-border/60 px-3 py-2">
        <span className="text-[11px] text-muted-foreground">
          {targetsProbing
            ? t('deviceList.bottomProbing')
            : t('deviceList.bottomOnlineCount', {
                count: Object.values(deviceReach).filter((e) => isReachOnline(e)).length,
              })}
        </span>
        <Button
          variant="ghost"
          size="icon-sm"
          onClick={refreshSendTargets}
          disabled={targetsProbing}
          title={t('deviceList.refreshReachTitle')}
        >
          <RefreshCw className={cn('size-3.5', targetsProbing && 'motion-safe:animate-spin')} />
        </Button>
      </div>
    </div>
  );
}
