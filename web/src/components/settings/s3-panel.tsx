'use client';

import Link from 'next/link';
import { useI18n } from '@/contexts/I18nContext';
import { localizedDocsHref, localeTagToPath } from '@/lib/i18nRouting';
import { useCallback, useEffect, useState } from 'react';
import {
  fetchMyMembership,
  getS3Config,
  saveS3Config,
  testS3Config,
  clearS3Config,
  switchToCustomS3,
  switchToHostedS3,
  type MembershipMe,
  type S3ConfigRequest,
  type S3StorageMode,
} from '@/lib/api';
import { analyticsTrack } from '@/lib/analytics';
import { AnalyticsEvents } from '@/lib/analyticsEvents';
import { logger } from '@/lib/logger';
import { formatUiMessage } from '@/lib/uiMessage';
import { formatFileSize } from '@/lib/fileUtils';
import { CircleAlert, CircleCheck, Cloud, Eye, EyeOff, RefreshCw, Settings2, BookOpen } from 'lucide-react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent } from '@/components/ui/card';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Progress } from '@/components/ui/progress';
import { Separator } from '@/components/ui/separator';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { cn } from '@/lib/utils';

const TAG = 's3-panel';

function displayEndpointHost(raw: string): string {
  const t = raw.trim();
  if (!t) return '';
  try {
    const url = new URL(t.includes('://') ? t : `https://${t}`);
    return url.hostname || t;
  } catch {
    return t;
  }
}

export type S3PanelProps = {
  idPrefix: string;
  /** When true, use full-page copy (larger intro) and wrap the form in a Card. */
  wrapInCard?: boolean;
};

export function S3Panel({ idPrefix, wrapInCard = false }: S3PanelProps) {
  const { localeTag, t } = useI18n();
  const [mode, setMode] = useState<S3StorageMode>('DISABLED');
  const [hostedAvailable, setHostedAvailable] = useState(false);
  /** 用户后端是否保存过自建 S3 凭证；HOSTED 模式下若为 true 可一键切回。 */
  const [customSaved, setCustomSaved] = useState(false);
  const [membership, setMembership] = useState<MembershipMe | null>(null);
  /** HOSTED 模式下，用户点击「切换为自建 S3」后展开表单。 */
  const [customFormRevealed, setCustomFormRevealed] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [testing, setTesting] = useState(false);
  const [clearing, setClearing] = useState(false);
  const [switchingBack, setSwitchingBack] = useState(false);
  const [switchingToCustom, setSwitchingToCustom] = useState(false);
  const [clearDialogOpen, setClearDialogOpen] = useState(false);
  const [switchBackDialogOpen, setSwitchBackDialogOpen] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [showSecret, setShowSecret] = useState(false);
  const [form, setForm] = useState<S3ConfigRequest>({
    endpoint: '',
    region: 'cn-east-1',
    bucket: '',
    accessKeyId: '',
    secretAccessKey: '',
    pathStyleAccessEnabled: true,
  });

  const isCustom = mode === 'CUSTOM';
  const isHosted = mode === 'HOSTED';
  const isDisabled = mode === 'DISABLED';
  const showCustomForm = isCustom || isDisabled || customFormRevealed;
  const showClearAction = isCustom && !hostedAvailable;

  const resetForm = () =>
    setForm({
      endpoint: '',
      region: 'cn-east-1',
      bucket: '',
      accessKeyId: '',
      secretAccessKey: '',
      pathStyleAccessEnabled: true,
    });

  useEffect(() => {
    Promise.all([
      getS3Config(),
      fetchMyMembership().catch((e) => {
        logger.warn(TAG, 'fetch membership failed', e);
        return null as MembershipMe | null;
      }),
    ])
      .then(([data, me]) => {
        logger.info(
          TAG,
          'load S3 config mode=', data.mode,
          'hostedAvailable=', data.hostedAvailable,
          'customSaved=', data.customSaved,
        );
        setMode(data.mode);
        setHostedAvailable(data.hostedAvailable);
        setCustomSaved(data.customSaved);
        setMembership(me);
        setCustomFormRevealed(false);
        if (data.mode === 'CUSTOM') {
          setForm((f) => ({
            ...f,
            endpoint: data.endpoint ?? '',
            region: data.region ?? 'cn-east-1',
            bucket: data.bucket ?? '',
            accessKeyId: data.accessKeyId ?? '',
            secretAccessKey: '',
            pathStyleAccessEnabled: data.pathStyleAccessEnabled ?? true,
          }));
        } else {
          resetForm();
        }
      })
      .finally(() => setLoading(false));
  }, []);

  const onSubmit = useCallback(
    async (e: React.FormEvent) => {
      e.preventDefault();
      setSaving(true);
      setErrorMessage(null);
      logger.info(TAG, 'save S3 config');
      try {
        await saveS3Config(form);

        setMode('CUSTOM');
        setCustomSaved(true);
        setCustomFormRevealed(false);
        setForm((f) => ({ ...f, secretAccessKey: '' }));
        toast.success(t('s3.saveOk'));
        logger.info(TAG, 'save S3 config success');
        analyticsTrack(AnalyticsEvents.s3SettingsSave, { result: 'success' });
      } catch (err) {
        logger.warn(TAG, 'save S3 config failed', err);
        setErrorMessage(t('s3.saveFail'));
        analyticsTrack(AnalyticsEvents.s3SettingsSave, { result: 'fail' });
      } finally {
        setSaving(false);
      }
    },
    [form, t],
  );

  const onTest = useCallback(async () => {
    setTesting(true);
    setErrorMessage(null);
    logger.info(TAG, 'test S3 config mode=', mode);
    try {
      await testS3Config();
      toast.success(t('s3.connectOk'));
      logger.info(TAG, 'test S3 config success');
    } catch (e) {
      const msg = e instanceof Error ? e.message : t('s3.connectFail');
      logger.warn(TAG, 'test S3 config failed', msg);
      setErrorMessage(msg);
    } finally {
      setTesting(false);
    }
  }, [mode, t]);

  const onConfirmClear = useCallback(async () => {
    setClearing(true);
    setErrorMessage(null);
    try {
      await clearS3Config();
      setMode('DISABLED');
      setCustomSaved(false);
      setCustomFormRevealed(false);
      resetForm();
      setClearDialogOpen(false);
      toast.success(t('s3.clearedOk'));
      logger.info(TAG, 'clear S3 config success');
    } catch (err) {
      logger.warn(TAG, 'clear S3 config failed', err);
      setErrorMessage(t('s3.clearFail'));
    } finally {
      setClearing(false);
    }
  }, [t]);

  const onConfirmSwitchBack = useCallback(async () => {
    setSwitchingBack(true);
    setErrorMessage(null);
    try {
      // 仅切换偏好，后端保留 BYO 凭证以便后续一键切回
      await switchToHostedS3();
      setMode('HOSTED');
      setCustomSaved(true);
      setCustomFormRevealed(false);
      resetForm();
      setSwitchBackDialogOpen(false);
      toast.success(t('s3.switchedBackOk'));
      logger.info(TAG, 'switch back to hosted success');
    } catch (err) {
      logger.warn(TAG, 'switch back to hosted failed', err);
      setErrorMessage(t('s3.switchBackFail'));
    } finally {
      setSwitchingBack(false);
    }
  }, [t]);

  const onSwitchToSavedCustom = useCallback(async () => {
    setSwitchingToCustom(true);
    setErrorMessage(null);
    try {
      await switchToCustomS3();
      const data = await getS3Config();
      setMode(data.mode);
      setHostedAvailable(data.hostedAvailable);
      setCustomSaved(data.customSaved);
      if (data.mode === 'CUSTOM') {
        setForm((f) => ({
          ...f,
          endpoint: data.endpoint ?? '',
          region: data.region ?? 'cn-east-1',
          bucket: data.bucket ?? '',
          accessKeyId: data.accessKeyId ?? '',
          secretAccessKey: '',
          pathStyleAccessEnabled: data.pathStyleAccessEnabled ?? true,
        }));
      }
      toast.success(t('s3.switchedToCustomOk'));
      logger.info(TAG, 'switch to saved custom S3 success');
    } catch (err) {
      logger.warn(TAG, 'switch to saved custom failed', err);
      setErrorMessage(t('s3.switchToCustomFail'));
    } finally {
      setSwitchingToCustom(false);
    }
  }, [t]);

  const pid = (name: string) => `${idPrefix}-${name}`;

  const loadingSpinner = (
    <div className="flex items-center justify-center py-8">
      <div className="animate-spin rounded-full h-7 w-7 border-2 border-primary border-t-transparent" />
    </div>
  );

  const epHost = displayEndpointHost(form.endpoint);
  const bucketTrim = form.bucket.trim();
  const summaryLine =
    epHost || bucketTrim
      ? bucketTrim
        ? t('s3.configuredSummary', { endpoint: epHost, bucket: bucketTrim })
        : epHost
      : null;

  const hostedUsedBytes = membership?.hostedUploadUsedBytes;
  const hostedQuotaBytes = membership?.hostedUploadQuotaBytes;
  const hasHostedUsage =
    hostedUsedBytes != null && hostedQuotaBytes != null;
  const usageRatio =
    hasHostedUsage && hostedQuotaBytes! > 0
      ? Math.min(100, (hostedUsedBytes! / hostedQuotaBytes!) * 100)
      : 0;
  const overQuota =
    hasHostedUsage && hostedQuotaBytes! > 0 && hostedUsedBytes! >= hostedQuotaBytes!;
  const nearQuota = hasHostedUsage && usageRatio >= 85 && !overQuota;

  const hostedCard = isHosted && (
    <div className="rounded-lg border border-primary/25 bg-primary/5 p-4">
      <div className="flex items-start gap-3">
        <span className="mt-0.5 inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-primary/12 text-primary">
          <Cloud className="size-4" aria-hidden />
        </span>
        <div className="min-w-0 flex-1">
          <p className="text-sm font-semibold text-foreground">{t('s3.hostedTitle')}</p>
          <p className="mt-1 text-sm text-muted-foreground">{t('s3.hostedBody')}</p>
        </div>
      </div>
      {hasHostedUsage && (
        <div className="mt-4 space-y-1.5">
          <div className="flex items-center justify-between gap-2 text-xs">
            <span className="font-medium text-muted-foreground">
              {t('s3.hostedUsageLabel')}
            </span>
            <span
              className={cn(
                'tabular-nums font-semibold',
                overQuota ? 'text-destructive' : 'text-foreground',
              )}
            >
              {hostedQuotaBytes! > 0
                ? t('s3.hostedUsageMonthly', {
                    used: formatFileSize(hostedUsedBytes!),
                    quota: formatFileSize(hostedQuotaBytes!),
                  })
                : t('s3.hostedUsageMonthlyUnlimited', {
                    used: formatFileSize(hostedUsedBytes!),
                  })}
            </span>
          </div>
          {hostedQuotaBytes! > 0 && (
            <Progress
              value={usageRatio}
              className={cn(
                'h-1.5',
                overQuota
                  ? '[&>div]:bg-destructive'
                  : nearQuota
                    ? '[&>div]:bg-amber-500'
                    : undefined,
              )}
            />
          )}
          <p className="text-[11px] text-muted-foreground">
            {t('s3.hostedUsageHint')}
          </p>
        </div>
      )}
      <div className="mt-4 flex flex-col gap-2 sm:flex-row">
        {customFormRevealed ? (
          <Button
            type="button"
            variant="ghost"
            className="sm:flex-1"
            onClick={() => setCustomFormRevealed(false)}
          >
            {t('s3.collapseCustomForm')}
          </Button>
        ) : customSaved ? (
          <Button
            type="button"
            variant="outline"
            className="sm:flex-1"
            onClick={() => void onSwitchToSavedCustom()}
            disabled={switchingToCustom}
          >
            <RefreshCw className="size-4" aria-hidden />
            {switchingToCustom ? t('s3.switching') : t('s3.useSavedCustom')}
          </Button>
        ) : (
          <Button
            type="button"
            variant="outline"
            className="sm:flex-1"
            onClick={() => setCustomFormRevealed(true)}
          >
            <Settings2 className="size-4" aria-hidden />
            {t('s3.switchToCustom')}
          </Button>
        )}
      </div>
    </div>
  );

  const customConfiguredBanner = isCustom && (
    <>
      <Alert className="border-primary/25 bg-primary/5 [&>svg]:text-primary">
        <CircleCheck className="size-4" aria-hidden />
        <AlertDescription className="text-foreground">
          {t('s3.customConfiguredHint')}
        </AlertDescription>
      </Alert>
      {summaryLine != null && (
        <p className="text-xs text-muted-foreground">{summaryLine}</p>
      )}
    </>
  );

  const disabledBanner = isDisabled && (
    <Alert>
      <CircleAlert className="size-4" aria-hidden />
      <AlertDescription>{t('s3.disabledHint')}</AlertDescription>
    </Alert>
  );

  const customForm = showCustomForm && (
    <form className={wrapInCard ? 'space-y-4' : 'space-y-3.5'} onSubmit={onSubmit}>
      <div className="space-y-2">
        <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
          {t('s3.sectionConnection')}
        </p>
        <div className={wrapInCard ? 'space-y-2' : 'space-y-1.5'}>
          <Label htmlFor={pid('endpoint')} className={wrapInCard ? undefined : 'text-xs'}>
            {t('s3.fieldEndpoint')}
          </Label>
          <Input
            id={pid('endpoint')}
            type="url"
            placeholder={t('s3.placeholderEndpoint')}
            value={form.endpoint}
            onChange={(e) => setForm((f) => ({ ...f, endpoint: e.target.value }))}
            required
          />
        </div>
        <div className={wrapInCard ? 'space-y-2' : 'space-y-1.5'}>
          <Label htmlFor={pid('region')} className={wrapInCard ? undefined : 'text-xs'}>
            {t('s3.fieldRegion')}
          </Label>
          <Input
            id={pid('region')}
            type="text"
            placeholder={t('s3.placeholderRegion')}
            value={form.region}
            onChange={(e) => setForm((f) => ({ ...f, region: e.target.value }))}
          />
        </div>
        <div className={wrapInCard ? 'space-y-2' : 'space-y-1.5'}>
          <Label htmlFor={pid('bucket')} className={wrapInCard ? undefined : 'text-xs'}>
            {t('s3.fieldBucket')}
          </Label>
          <Input
            id={pid('bucket')}
            type="text"
            placeholder={t('s3.placeholderBucket')}
            value={form.bucket}
            onChange={(e) => setForm((f) => ({ ...f, bucket: e.target.value }))}
            required
          />
        </div>
        <div
          className={cn(
            'flex items-start gap-3 rounded-lg border border-border/60 bg-muted/30 p-3',
            wrapInCard ? 'mt-2' : 'mt-1.5',
          )}
        >
          <Checkbox
            id={pid('path-style')}
            checked={form.pathStyleAccessEnabled !== false}
            onCheckedChange={(checked) =>
              setForm((f) => ({
                ...f,
                pathStyleAccessEnabled: checked === true,
              }))
            }
          />
          <div className="min-w-0 flex-1 space-y-0.5">
            <Label htmlFor={pid('path-style')} className="cursor-pointer text-sm font-medium">
              {t('s3.fieldPathStyle')}
            </Label>
            <p className="text-xs text-muted-foreground">{t('s3.pathStyleHint')}</p>
          </div>
        </div>
      </div>

      <Separator />

      <div className="space-y-2">
        <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
          {t('s3.sectionCredentials')}
        </p>
        <div className={wrapInCard ? 'space-y-2' : 'space-y-1.5'}>
          <Label htmlFor={pid('ak')} className={wrapInCard ? undefined : 'text-xs'}>
            {t('s3.fieldAccessKeyId')}
          </Label>
          <Input
            id={pid('ak')}
            type="text"
            placeholder={t('s3.placeholderAccessKeyId')}
            value={form.accessKeyId}
            onChange={(e) => setForm((f) => ({ ...f, accessKeyId: e.target.value }))}
            required
          />
        </div>
        <div className={wrapInCard ? 'space-y-2' : 'space-y-1.5'}>
          <Label htmlFor={pid('sk')} className={wrapInCard ? undefined : 'text-xs'}>
            {t('s3.fieldSecretAccessKey')}
          </Label>
          <div className="relative">
            <Input
              id={pid('sk')}
              type={showSecret ? 'text' : 'password'}
              placeholder={
                isCustom
                  ? t('s3.secretLeaveBlank')
                  : wrapInCard
                    ? t('s3.placeholderSecretExample')
                    : ''
              }
              value={form.secretAccessKey ?? ''}
              onChange={(e) => setForm((f) => ({ ...f, secretAccessKey: e.target.value }))}
              className="pr-10"
              required={!isCustom}
            />
            <Button
              type="button"
              variant="ghost"
              size="icon"
              className="absolute right-0 top-0 h-9 w-9 text-muted-foreground"
              onClick={() => setShowSecret((v) => !v)}
              aria-label={showSecret ? t('s3.a11yHideSecret') : t('s3.a11yShowSecret')}
            >
              {showSecret ? <EyeOff className="size-4" /> : <Eye className="size-4" />}
            </Button>
          </div>
        </div>
      </div>

      <div className={cn('flex flex-col gap-3 pt-2', wrapInCard ? 'sm:flex-row' : '')}>
        <Button type="submit" disabled={saving} className={wrapInCard ? 'sm:flex-1' : 'w-full'}>
          {saving ? t('s3.saveSaving') : t('s3.saveButton')}
        </Button>
        <Button
          type="button"
          variant="outline"
          onClick={onTest}
          disabled={testing || !isCustom}
          className={wrapInCard ? 'sm:flex-1' : 'w-full'}
        >
          {testing ? t('s3.testTesting') : t('s3.testButton')}
        </Button>
      </div>

      {isCustom && hostedAvailable && (
        <Button
          type="button"
          variant="ghost"
          className="w-full text-muted-foreground hover:text-foreground"
          onClick={() => setSwitchBackDialogOpen(true)}
          disabled={switchingBack}
        >
          <Cloud className="size-4" aria-hidden />
          {switchingBack ? t('s3.switching') : t('s3.switchBackToHosted')}
        </Button>
      )}

      {errorMessage && (
        <Alert variant="destructive">
          <CircleAlert className="size-4 shrink-0" />
          <AlertDescription>{formatUiMessage(errorMessage, t)}</AlertDescription>
        </Alert>
      )}
    </form>
  );

  const formBlock = !loading && (
    <>
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0 flex-1 space-y-3">
          <p
            className={cn(
              'text-muted-foreground',
              wrapInCard ? 'text-sm' : 'text-sm leading-relaxed',
            )}
          >
            {t('s3.intro')}
          </p>
          <Link
            href={localizedDocsHref(localeTagToPath(localeTag), 's3')}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1.5 text-sm font-medium text-primary underline-offset-4 hover:underline"
          >
            <BookOpen className="size-4 shrink-0" aria-hidden />
            {t('s3.docsLink')}
          </Link>
        </div>
        {showClearAction && (
          <Button
            type="button"
            variant="outline"
            className="shrink-0 border-destructive/40 text-destructive hover:bg-destructive/10"
            disabled={loading || clearing}
            onClick={() => setClearDialogOpen(true)}
          >
            {clearing ? t('s3.clearing') : t('s3.clearButton')}
          </Button>
        )}
      </div>

      {hostedCard}
      {customConfiguredBanner}
      {disabledBanner}
      {customForm}

      <Dialog open={clearDialogOpen} onOpenChange={setClearDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('s3.clearDialogTitle')}</DialogTitle>
            <DialogDescription>{t('s3.clearDialogBody')}</DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => setClearDialogOpen(false)}>
              {t('common.cancel')}
            </Button>
            <Button
              type="button"
              variant="destructive"
              disabled={clearing}
              onClick={() => void onConfirmClear()}
            >
              {clearing ? t('s3.clearing') : t('s3.clearDialogConfirm')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={switchBackDialogOpen} onOpenChange={setSwitchBackDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('s3.switchBackTitle')}</DialogTitle>
            <DialogDescription>{t('s3.switchBackBody')}</DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => setSwitchBackDialogOpen(false)}
            >
              {t('common.cancel')}
            </Button>
            <Button
              type="button"
              disabled={switchingBack}
              onClick={() => void onConfirmSwitchBack()}
            >
              {switchingBack ? t('s3.switching') : t('s3.switchBackConfirm')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );

  const inner = loading ? loadingSpinner : formBlock;

  if (wrapInCard) {
    return (
      <div className="space-y-4">
        <Card>
          <CardContent className="space-y-4 pt-5">{inner}</CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <Card>
        <CardContent className="space-y-4 pt-5">{inner}</CardContent>
      </Card>
    </div>
  );
}
