'use client';

import { useRef, useState } from 'react';
import { useChatContext } from '@/contexts/ChatContext';
import { useI18n } from '@/contexts/I18nContext';
import { useSendShortcutMode } from '@/hooks/useSendShortcutMode';
import { isMacPlatform } from '@/lib/shortcutPreferences';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { extractClipboardFiles } from '@/lib/clipboardFiles';
import { CirclePlus, Send, X } from 'lucide-react';

export function MessageInput() {
  const { t } = useI18n();
  const {
    sendTextMessage,
    sending,
    handleFileSelect,
    addPendingFiles,
    selectedDeviceId,
  } = useChatContext();

  const [input, setInput] = useState('');
  const [sendShortcutMode] = useSendShortcutMode();
  const fileInputRef = useRef<HTMLInputElement>(null);

  const sendTooltip =
    sendShortcutMode === 'enter'
      ? t('chat.input.sendEnter')
      : isMacPlatform()
        ? t('chat.input.sendModifierEnterMac')
        : t('chat.input.sendModifierEnter');

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault();
    const text = input.trim();
    if (!text || sending) return;
    setInput('');
    await sendTextMessage(text);
  };

  const disabled = !selectedDeviceId;

  return (
    <form
      onSubmit={handleSend}
      className="shrink-0 bg-card px-3 py-2 sm:px-4 sm:py-3"
    >
      <div className="flex gap-1 items-center">
        <input
          type="file"
          ref={fileInputRef}
          onChange={handleFileSelect}
          className="hidden"
          multiple
        />
        <div
          className={cn(
            'relative flex-1 min-w-0 overflow-hidden rounded-full border border-input bg-muted/50 transition-colors',
            'focus-within:border-ring focus-within:ring-2 focus-within:ring-inset focus-within:ring-ring/40',
            disabled && 'opacity-50',
          )}
        >
          <textarea
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onPaste={(e) => {
              if (disabled) return;
              const files = extractClipboardFiles(e.clipboardData);
              if (files.length === 0) return;
              e.preventDefault();
              addPendingFiles(files);
            }}
            onKeyDown={(e) => {
              if (e.key !== 'Enter' || e.nativeEvent.isComposing) return;
              const shouldSend =
                sendShortcutMode === 'enter'
                  ? !e.shiftKey
                  : e.ctrlKey || e.metaKey;
              if (shouldSend) {
                e.preventDefault();
                handleSend(e);
              }
            }}
            placeholder={disabled ? t('chat.header.pickDeviceHint') : t('chat.input.placeholder')}
            disabled={sending || disabled}
            rows={1}
            className={cn(
              'w-full border-0 bg-transparent py-2.5 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-0 disabled:opacity-50 resize-none overflow-y-auto max-h-24 field-sizing-content',
              input.trim() ? 'pl-4 pr-10' : 'px-4',
            )}
            style={{ fieldSizing: 'content' } as React.CSSProperties}
          />
          {input.trim() !== '' && (
            <button
              type="button"
              title={t('chat.input.clear')}
              className="absolute inset-y-0 right-1 z-10 flex w-8 items-center justify-center rounded-full text-muted-foreground hover:text-foreground hover:bg-muted/80"
              onClick={() => setInput('')}
            >
              <X className="size-4.5 shrink-0" strokeWidth={2.5} />
            </button>
          )}
        </div>
        {input.trim() !== '' ? (
          <Button
            type="submit"
            size="icon"
            disabled={sending || disabled}
            className="size-11 shrink-0 rounded-full bg-primary text-primary-foreground shadow-sm hover:bg-primary/90 hover:text-primary-foreground disabled:opacity-50 [&_svg]:stroke-[2.5]"
            title={sendTooltip}
          >
            <Send className="size-5" />
          </Button>
        ) : (
          <Button
            type="button"
            variant="ghost"
            size="icon"
            disabled={disabled}
            className="size-11 shrink-0 rounded-full text-muted-foreground hover:text-foreground"
            title={t('chat.input.pickFile')}
            onClick={() => fileInputRef.current?.click()}
          >
            <CirclePlus className="size-[26px]" />
          </Button>
        )}
      </div>
    </form>
  );
}
