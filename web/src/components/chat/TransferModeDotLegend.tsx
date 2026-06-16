'use client';

import { useState } from 'react';
import { CircleHelp } from 'lucide-react';
import { useI18n } from '@/contexts/I18nContext';
import {
  LEGEND_STATES,
  transferModeDotClassName,
  transferModeDotLegendLabel,
} from '@/lib/transferModeDot';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { cn } from '@/lib/utils';

export function TransferModeDotLegendButton() {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);

  return (
    <>
      <Button
        type="button"
        variant="ghost"
        size="icon-sm"
        className="size-[22px] shrink-0"
        title={t('chat.transportModeDot.legendTooltip')}
        onClick={() => setOpen(true)}
      >
        <CircleHelp className="size-3.5 text-muted-foreground" />
      </Button>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>{t('chat.transportModeDot.legendTitle')}</DialogTitle>
          </DialogHeader>
          <ul className="space-y-3">
            {LEGEND_STATES.map((state) => (
              <li key={state} className="flex items-start gap-3">
                <span
                  className={cn(
                    'mt-1 size-2 shrink-0 rounded-full',
                    transferModeDotClassName(state),
                  )}
                />
                <span className="text-sm text-foreground">
                  {transferModeDotLegendLabel(t, state)}
                </span>
              </li>
            ))}
          </ul>
          <DialogFooter showCloseButton>
            <Button type="button" onClick={() => setOpen(false)}>
              {t('common.done')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
