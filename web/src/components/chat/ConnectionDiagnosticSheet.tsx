'use client';

import { useEffect, useState } from 'react';
import { CircleHelp, Loader2, CheckCircle2, XCircle } from 'lucide-react';
import { useI18n } from '@/contexts/I18nContext';
import {
  type ConnectionDiagnosticState,
  type DiagnosticStep,
  type DiagnosticStepId,
  diagnosticStepHelp,
  formatDiagnosticElapsed,
} from '@/lib/connectionDiagnostic';
import { cn } from '@/lib/utils';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  state: ConnectionDiagnosticState | null;
};

export function ConnectionDiagnosticSheet({ open, onOpenChange, state }: Props) {
  const { t } = useI18n();
  const [, tick] = useState(0);
  const [helpStepId, setHelpStepId] = useState<DiagnosticStepId | null>(null);

  useEffect(() => {
    if (!open || !state?.running) return;
    const id = window.setInterval(() => tick((n) => n + 1), 200);
    return () => window.clearInterval(id);
  }, [open, state?.running]);

  useEffect(() => {
    if (!open) setHelpStepId(null);
  }, [open]);

  const help = helpStepId ? diagnosticStepHelp(t, helpStepId) : null;

  return (
    <>
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent
          showCloseButton
          className={cn(
            'top-auto bottom-0 left-1/2 max-h-[80vh] w-full max-w-lg translate-x-[-50%] translate-y-0',
            'rounded-b-none rounded-t-2xl border-b-0 p-0 sm:max-w-lg',
            'data-open:slide-in-from-bottom-8 data-closed:slide-out-to-bottom-8',
          )}
        >
          <div className="flex max-h-[80vh] flex-col">
            <DialogHeader className="shrink-0 border-b border-border/60 px-5 pt-5 pb-3">
              <DialogTitle>{t('chat.connectionDiag.title')}</DialogTitle>
              <DialogDescription>
                {state?.running
                  ? t('chat.connectionDiag.subtitleRunning', {
                      peer: state?.peerLabel ?? '',
                    })
                  : t('chat.connectionDiag.subtitleDone', {
                      peer: state?.peerLabel ?? '',
                    })}
              </DialogDescription>
            </DialogHeader>

            <div className="min-h-0 flex-1 overflow-y-auto px-5 py-3">
              <div className="flex flex-col gap-2">
                {state?.steps.map((step) => (
                  <DiagnosticStepRow
                    key={step.id}
                    step={step}
                    onHelp={() => setHelpStepId(step.id)}
                  />
                ))}
              </div>

              {state?.summary ? (
                <div className="mt-3 rounded-xl border border-border/60 bg-muted/50 p-3 text-sm font-medium">
                  {state.summary}
                </div>
              ) : null}
            </div>
          </div>
        </DialogContent>
      </Dialog>

      <Dialog open={helpStepId != null} onOpenChange={(o) => !o && setHelpStepId(null)}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>{help?.title}</DialogTitle>
          </DialogHeader>
          <DialogDescription className="whitespace-pre-line leading-relaxed">
            {help?.body}
          </DialogDescription>
          <div className="flex justify-end pt-2">
            <Button type="button" onClick={() => setHelpStepId(null)}>
              {t('common.confirm')}
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
}

function DiagnosticStepRow({
  step,
  onHelp,
}: {
  step: DiagnosticStep;
  onHelp: () => void;
}) {
  const { t } = useI18n();
  const elapsed = displayElapsed(step);

  return (
    <div className="rounded-xl border border-border/60 bg-muted/40 p-3">
      <div className="flex items-start gap-2">
        <StepStatusIcon status={step.status} />
        <div className="min-w-0 flex-1">
          <div className="flex items-start gap-1">
            <p className="min-w-0 flex-1 text-sm font-semibold">{step.title}</p>
            <button
              type="button"
              className="shrink-0 rounded-md p-0.5 text-muted-foreground hover:bg-muted hover:text-foreground"
              title={t('chat.connectionDiag.helpTooltip')}
              onClick={onHelp}
            >
              <CircleHelp className="size-3.5" />
            </button>
            {elapsed != null ? (
              <span className="shrink-0 text-[10px] text-muted-foreground">
                {t('chat.connectionDiag.elapsed', { elapsed })}
              </span>
            ) : null}
          </div>
          <span
            className={cn(
              'mt-1 inline-flex rounded-full px-1.5 py-0.5 text-[10px] font-medium',
              step.status === 'pending' && 'bg-muted text-muted-foreground',
              step.status === 'running' && 'bg-primary/10 text-primary',
              step.status === 'success' && 'bg-emerald-500/10 text-emerald-600',
              step.status === 'failure' && 'bg-destructive/10 text-destructive',
            )}
          >
            {statusLabel(t, step.status)}
          </span>
          {step.reason ? (
            <p className="mt-1.5 pl-0.5 text-xs text-muted-foreground">{step.reason}</p>
          ) : null}
        </div>
      </div>
    </div>
  );
}

function StepStatusIcon({ status }: { status: DiagnosticStep['status'] }) {
  switch (status) {
    case 'pending':
      return <span className="mt-0.5 size-3.5 shrink-0 rounded-full bg-muted-foreground/30" />;
    case 'running':
      return <Loader2 className="mt-0.5 size-4 shrink-0 animate-spin text-primary" />;
    case 'success':
      return <CheckCircle2 className="mt-0.5 size-4 shrink-0 text-emerald-500" />;
    case 'failure':
      return <XCircle className="mt-0.5 size-4 shrink-0 text-destructive" />;
  }
}

function displayElapsed(step: DiagnosticStep): string | null {
  if (step.status === 'pending') return null;
  if (step.elapsedMs != null) return formatDiagnosticElapsed(step.elapsedMs);
  if (step.status === 'running' && step.startedAt != null) {
    return formatDiagnosticElapsed(Date.now() - step.startedAt);
  }
  return null;
}

function statusLabel(
  t: ReturnType<typeof useI18n>['t'],
  status: DiagnosticStep['status'],
): string {
  switch (status) {
    case 'pending':
      return t('chat.connectionDiag.statusPending');
    case 'running':
      return t('chat.connectionDiag.statusRunning');
    case 'success':
      return t('chat.connectionDiag.statusSuccess');
    case 'failure':
      return t('chat.connectionDiag.statusFailure');
  }
}
