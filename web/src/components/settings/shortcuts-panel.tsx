'use client';

import { analyticsTrack } from '@/lib/analytics';
import { AnalyticsEvents } from '@/lib/analyticsEvents';
import { isMacPlatform } from '@/lib/shortcutPreferences';
import type { SendShortcutMode } from '@/lib/shortcutPreferences';
import { useSendShortcutMode } from '@/hooks/useSendShortcutMode';
import { useAutoCopyIncomingText } from '@/hooks/useAutoCopyIncomingText';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Checkbox } from '@/components/ui/checkbox';
import { Label } from '@/components/ui/label';
import { Separator } from '@/components/ui/separator';
import { useI18n } from '@/contexts/I18nContext';

export function ShortcutsPanel() {
  const { t } = useI18n();
  const [sendShortcutMode, setSendShortcutMode] = useSendShortcutMode();
  const [autoCopyIncomingText, setAutoCopyIncomingText] = useAutoCopyIncomingText();
  const modifierShortcutLabel = isMacPlatform()
    ? t('shortcuts.sendModifierMac')
    : t('shortcuts.sendModifier');

  const applySendShortcut = (mode: SendShortcutMode) => {
    setSendShortcutMode(mode);
    analyticsTrack(AnalyticsEvents.settingChanged, {
      key: 'send_shortcut',
      value: mode,
    });
  };

  const applyAutoCopy = (enabled: boolean) => {
    setAutoCopyIncomingText(enabled);
    analyticsTrack(AnalyticsEvents.settingChanged, {
      key: 'auto_copy_received_text',
      value: String(enabled),
    });
  };

  return (
    <Card>
      <CardContent className="space-y-4 pt-3.5 pb-3.5">
        <div className="space-y-2">
          <p className="text-sm font-medium text-foreground">{t('shortcuts.sendTitle')}</p>
          <p className="text-xs text-muted-foreground">{t('shortcuts.sendDescription')}</p>
          <div className="flex flex-wrap gap-2 pt-1">
            <Button
              variant={sendShortcutMode === 'enter' ? 'default' : 'secondary'}
              size="sm"
              onClick={() => applySendShortcut('enter')}
            >
              {t('shortcuts.sendEnter')}
            </Button>
            <Button
              variant={sendShortcutMode === 'modifier_enter' ? 'default' : 'secondary'}
              size="sm"
              onClick={() => applySendShortcut('modifier_enter')}
            >
              {modifierShortcutLabel}
            </Button>
          </div>
        </div>
        <Separator />
        <p className="text-xs text-muted-foreground">{t('shortcuts.sendButtonHint')}</p>
        <Separator />
        <div className="flex items-start gap-3">
          <Checkbox
            id="auto-copy-received-text"
            checked={autoCopyIncomingText}
            onCheckedChange={(checked) => applyAutoCopy(checked === true)}
          />
          <div className="min-w-0 flex-1 space-y-0.5">
            <Label htmlFor="auto-copy-received-text" className="cursor-pointer text-sm font-medium">
              {t('shortcuts.autoCopyReceivedTextTitle')}
            </Label>
            <p className="text-xs text-muted-foreground">{t('shortcuts.autoCopyReceivedTextDescription')}</p>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
