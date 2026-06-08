'use client';

import { useCallback, useRef, useState } from 'react';
import { useChatContext, S3_VIRTUAL_DEVICE_ID } from '@/contexts/ChatContext';
import { ChatHeader } from '@/components/chat/ChatHeader';
import { MessageList } from '@/components/chat/MessageList';
import { MessageInput } from '@/components/chat/MessageInput';
import { TransferModeBar } from '@/components/chat/TransferModeBar';
import { ConnectionDiagnosticSheet } from '@/components/chat/ConnectionDiagnosticSheet';
import { PendingFilesBar } from '@/components/chat/PendingFilesBar';
import { ErrorBar } from '@/components/chat/ErrorBar';
import { cn } from '@/lib/utils';
import { useI18n } from '@/contexts/I18nContext';

export function ChatDetailPanel({
  onBack,
  showBackButton,
  className,
}: {
  onBack?: () => void;
  showBackButton?: boolean;
  className?: string;
}) {
  const { t } = useI18n();
  const {
    selectedDeviceId,
    setPendingFiles,
    setFileError,
    connectionDiagnostic,
    diagnosticSheetOpen,
    setDiagnosticSheetOpen,
  } = useChatContext();
  const [isDraggingOver, setIsDraggingOver] = useState(false);
  const dragCounterRef = useRef(0);

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.dataTransfer.types.includes('Files')) {
      e.dataTransfer.dropEffect = 'copy';
      dragCounterRef.current += 1;
      setIsDraggingOver(true);
    }
  }, []);

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    dragCounterRef.current -= 1;
    if (dragCounterRef.current === 0) {
      setIsDraggingOver(false);
    }
  }, []);

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    dragCounterRef.current = 0;
    setIsDraggingOver(false);
    const files = e.dataTransfer.files;
    if (!files || files.length === 0) return;
    const fileList = Array.from(files);
    setFileError(null);
    setPendingFiles((prev) => [...prev, ...fileList]);
  }, [setFileError, setPendingFiles]);

  return (
    <div
      className={cn('relative flex min-h-0 min-w-0 flex-1 flex-col bg-card', className)}
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
    >
      <ChatHeader onBack={onBack} showBackButton={showBackButton} />

      {isDraggingOver && (
        <div className="pointer-events-none absolute inset-0 z-50 m-2 flex items-center justify-center rounded-2xl border-2 border-dashed border-primary/55 bg-card/78 backdrop-blur-sm">
          <p className="font-display text-sm tracking-tight text-muted-foreground">{t('chat.empty.dropHint')}</p>
        </div>
      )}

      {selectedDeviceId ? (
        <>
          <TransferModeBar />
          <MessageList />
          <ErrorBar />
          <PendingFilesBar />
          <MessageInput />
        </>
      ) : (
        <div className="flex flex-1 flex-col items-center justify-center gap-4 text-muted-foreground">
          <div className="size-16 rounded-2xl bg-muted/50 flex items-center justify-center">
            <svg className="size-8 opacity-30" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.2}>
              <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
            </svg>
          </div>
          <p className="text-sm">{t('chat.header.pickDeviceHint')}</p>
        </div>
      )}

      <ConnectionDiagnosticSheet
        open={diagnosticSheetOpen}
        onOpenChange={setDiagnosticSheetOpen}
        state={connectionDiagnostic}
      />
    </div>
  );
}
