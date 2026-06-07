'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useVirtualizer } from '@tanstack/react-virtual';
import { useAuth } from '@/contexts/AuthContext';
import { useI18n } from '@/contexts/I18nContext';
import { useCentrifuge } from '@/hooks/useCentrifuge';
import { sendMessage, getMessageHistory, listDevices, hasS3Config, registerDevice, updateDevicePresence, deleteMessage, updateDevice } from '@/lib/api';
import { S3TransferService } from '@/lib/services/s3Transfer';
import type { CloudTransferService } from '@/lib/services/cloudTransfer';
import { transferStateManager } from '@/lib/services/transferStateManager';
import type { MessageEnvelope, ChatMessage } from '@/lib/api';
import type { DeviceDto } from '@/lib/api';
import { getOrCreateDeviceId, getDeviceName, getOrCreatePresenceSessionId, generateUUID } from '@/lib/deviceId';
import { logger } from '@/lib/logger';
import { trySendFileViaLan, probeHttpWeb, TRANSFER_STALL_TIMEOUT_MESSAGE } from '@/lib/fileTransfer';
import { SpeedTracker } from '@/lib/speedTracker';
import { WebRTCManager, isWebRTCSignal } from '@/lib/webrtc';
import type { WebRTCSignal, FileMetadata } from '@/lib/webrtc';
import { MessageCircle, X, Send, ChevronDown, Circle, CircleCheck, MonitorSmartphone, CirclePlus } from 'lucide-react';
import { MessageBubble } from './MessageBubble';
import { senderDisplayLabel } from '@/lib/senderDisplay';
import { normalizeMessageLocalId, rowMatchesLocalId } from '@/lib/chatMessageDedupe';
import { DeviceSendPanel } from './DeviceSendPanel';
import { Button } from '@/components/ui/button';
import { useMinWidthMd } from '@/hooks/useMediaQuery';
import { useSendTargetProbes, getReachDisplayStatus, type ReachStatus } from '@/hooks/useSendTargetProbes';
import {
  loadDesktopPanelOpen,
  loadSelectedTargets,
  loadSendMode,
  persistDesktopPanelOpen,
  persistSelectedTargets,
  persistSendMode,
  type WebSendMode,
} from '@/lib/sendTargetStorage';
import { cn } from '@/lib/utils';
import { formatUiMessage } from '@/lib/uiMessage';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { runWithConcurrency, AsyncSemaphore } from '@/lib/concurrency';

const TAG = 'Chat';
const MAX_PARALLEL_FILE_SENDS = 3;
const MAX_PARALLEL_WEBRTC_TARGETS = 2;
const cloudTransfer: CloudTransferService = new S3TransferService();
/** Number of messages per page for pagination. Adjust for debugging. */
const CHAT_PAGE_SIZE = 20;
const EPHEMERAL_TYPES = new Set([
  'lan_file_offer', 'lan_pull_probe', 'lan_pull_probe_result',
  'lan_http_probe', 'lan_http_probe_result',
  'webrtc_probe', 'webrtc_probe_result',
  'webrtc_offer', 'webrtc_answer', 'webrtc_ice_candidate', 'webrtc_transfer_cancel',
]);
const SCROLL_TO_BOTTOM_THRESHOLD = 120;

function isProgressOnlyPatch(patch: Partial<ChatMessage>): boolean {
  const ks = Object.keys(patch);
  if (ks.length === 0) return false;
  return ks.every((k) => k === '_progress' || k === '_speed');
}

/** 稳定键，仅依赖服务端 id 或本地 _localId，避免列表变化后选中态错乱 */
function getMessageSelectKey(msg: ChatMessage): string | null {
  if (msg.id != null) return `id:${msg.id}`;
  if (msg._localId) return `local:${msg._localId}`;
  return null;
}

/** 传输中不显示 hover 多选（对齐 Flutter PC） */
function isMessageTransferring(msg: ChatMessage): boolean {
  const s = msg._status;
  if (s === 'uploading' || s === 'downloading') return true;
  if (msg.type === 'file' && s === 'sending') return true;
  return false;
}

export type ChatSelectionChrome = {
  selectedCount: number;
  allSelected: boolean;
  onExit: () => void;
  onToggleSelectAll: () => void;
  onBulkDelete: () => void;
};

export function Chat({
  onConnectedChange,
  onSelectionChromeChange,
}: {
  onConnectedChange?: (connected: boolean) => void;
  /** 多选时同步到顶栏（与 Flutter PC AppBar 一致） */
  onSelectionChromeChange?: (state: ChatSelectionChrome | null) => void;
}) {
  const { userId } = useAuth();
  const { t } = useI18n();
  const sendModeLabel = useCallback(
    (mode: WebSendMode) => {
      switch (mode) {
        case 'lan':
          return t('chat.transferBar.lan');
        case 'webrtc':
          return t('chat.transferBar.webrtc');
        case 's3':
          return t('chat.transferBar.s3');
        default:
          return t('chat.transferBar.lan');
      }
    },
    [t],
  );
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const pendingPatchesRef = useRef<Map<string, Partial<ChatMessage>>>(new Map());
  const rafFlushingRef = useRef<number | null>(null);
  const prevMessageCountRef = useRef(0);
  const pullSemaphoreRef = useRef(new AsyncSemaphore(3));
  const sendSingleFileRef = useRef<(file: File, useLan: boolean, targetDevices: DeviceDto[]) => Promise<void>>(async () => {});
  const sendFilesViaWebRTCRef = useRef<(files: File[], targetDeviceId: string) => Promise<void>>(async () => {});

  const flushProgressPatches = useCallback(() => {
    rafFlushingRef.current = null;
    const pending = pendingPatchesRef.current;
    if (pending.size === 0) return;
    pendingPatchesRef.current = new Map();
    setMessages((prev) => {
      let changed = false;
      const next = [...prev];
      for (const [localId, patch] of pending) {
        const idx = next.findIndex((m) => rowMatchesLocalId(m, localId));
        if (idx < 0) continue;
        changed = true;
        next[idx] = { ...next[idx], ...patch };
      }
      return changed ? next : prev;
    });
  }, []);

  const updateMessageByLocalId = useCallback(
    (localId: string, patch: Partial<ChatMessage>) => {
      if (!isProgressOnlyPatch(patch)) {
        if (rafFlushingRef.current != null) {
          cancelAnimationFrame(rafFlushingRef.current);
          rafFlushingRef.current = null;
        }
        const snap = pendingPatchesRef.current;
        pendingPatchesRef.current = new Map();
        snap.delete(localId);
        setMessages((prev) => {
          const next = [...prev];
          let changed = false;
          const apply = (id: string, p: Partial<ChatMessage>) => {
            const idx = next.findIndex((m) => rowMatchesLocalId(m, id));
            if (idx < 0) return;
            next[idx] = { ...next[idx], ...p };
            changed = true;
          };
          for (const [id, p] of snap) apply(id, p);
          apply(localId, patch);
          return changed ? next : prev;
        });
        return;
      }

      pendingPatchesRef.current.set(localId, { ...pendingPatchesRef.current.get(localId), ...patch });
      if (rafFlushingRef.current == null) {
        rafFlushingRef.current = requestAnimationFrame(() => flushProgressPatches());
      }
    },
    [flushProgressPatches],
  );
  const [input, setInput] = useState('');
  const [sending, setSending] = useState(false);
  const [sendError, setSendError] = useState<string | null>(null);
  const [fileError, setFileError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const listRef = useRef<HTMLDivElement>(null);

  const rowVirtualizer = useVirtualizer({
    count: messages.length,
    getScrollElement: () => listRef.current,
    estimateSize: () => 104,
    overscan: 12,
    getItemKey: (index) => {
      const m = messages[index];
      if (!m) return index;
      const mid = (m as ChatMessage & { id?: number }).id;
      return m._localId ?? `srv-${mid ?? 'noid'}-${m.ts}-${index}`;
    },
  });

  const [pendingFiles, setPendingFiles] = useState<File[]>([]);
  const [showManageSheet, setShowManageSheet] = useState(false);
  const [devices, setDevices] = useState<DeviceDto[]>([]);
  const [sendMode, setSendMode] = useState<WebSendMode>('lan');
  const [selectedTargets, setSelectedTargets] = useState<Set<string>>(() => new Set());
  const presenceSessionId = useMemo(() => getOrCreatePresenceSessionId(), []);
  const [desktopPanelVisible, setDesktopPanelVisible] = useState(true);
  const [mobilePanelOpen, setMobilePanelOpen] = useState(false);
  /** Increment to re-run LAN/WebRTC reach probes (see refreshSendTargets). */
  const [targetProbeToken, setTargetProbeToken] = useState(0);
  const [probeForceAll, setProbeForceAll] = useState(false);
  const storageHydratedRef = useRef(false);
  const activeTransfersRef = useRef<Map<string, AbortController>>(new Map());
  const speedTrackersRef = useRef<Map<string, SpeedTracker>>(new Map());
  const webrtcManagerRef = useRef<WebRTCManager | null>(null);
  const webrtcFileLocalIdMap = useRef<Map<string, string>>(new Map());
  const webrtcFileSizeMap = useRef<Map<string, number>>(new Map());
  const pendingWebRTCProbesRef = useRef<Map<string, (success: boolean) => void>>(new Map());
  const pendingLanHttpProbesRef = useRef<Map<string, (result: { success: boolean; lanHttpUrl?: string; senderReachable?: boolean }) => void>>(new Map());

  type RetryInfo = { file: File; channel: 'lan' | 's3' | 'webrtc'; targetDevices: DeviceDto[]; webrtcTargetDeviceId?: string };
  const retryInfoRef = useRef<Map<string, RetryInfo>>(new Map());

  const [loadingMore, setLoadingMore] = useState(false);
  const loadingMoreRef = useRef(false);
  const hasNoMoreRef = useRef(false);
  const prependingRef = useRef(false);
  const [isDraggingOver, setIsDraggingOver] = useState(false);
  const dragCounterRef = useRef(0);
  const [showScrollToBottom, setShowScrollToBottom] = useState(false);
  const [selectMode, setSelectMode] = useState(false);
  const [selectedKeys, setSelectedKeys] = useState<Set<string>>(() => new Set());

  if (!webrtcManagerRef.current) {
    webrtcManagerRef.current = new WebRTCManager();
  }

  useEffect(() => {
    const mgr = webrtcManagerRef.current;
    if (!mgr) return;

    mgr.onProgress = (fileId, received, total) => {
      const localId = webrtcFileLocalIdMap.current.get(fileId);
      if (!localId) return;
      const pct = total > 0 ? Math.min(Math.round((received / total) * 100), 100) : 0;
      const tracker = speedTrackersRef.current.get(localId);
      if (tracker) tracker.update(received);
      updateMessageByLocalId(localId, { _progress: pct, _speed: tracker?.formatted });
    };

    mgr.onFileReceived = (fileId, fileName, blob) => {
      const localId = webrtcFileLocalIdMap.current.get(fileId) ?? generateUUID();
      webrtcFileLocalIdMap.current.delete(fileId);
      const fileSize = webrtcFileSizeMap.current.get(fileId);
      webrtcFileSizeMap.current.delete(fileId);
      speedTrackersRef.current.delete(localId);

      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = fileName;
      a.click();
      URL.revokeObjectURL(url);

      updateMessageByLocalId(localId, {
        _status: 'sent',
        _progress: undefined,
        _speed: undefined,
        payload: { fileName, webrtc: true, ...(fileSize != null && fileSize > 0 ? { size: fileSize } : {}) },
      });
      logger.info(TAG, 'WebRTC file received', fileName);
    };

    mgr.onFileSent = (fileId, fileName) => {
      const localId = webrtcFileLocalIdMap.current.get(fileId);
      if (!localId) return;
      webrtcFileLocalIdMap.current.delete(fileId);
      const fileSize = webrtcFileSizeMap.current.get(fileId);
      webrtcFileSizeMap.current.delete(fileId);
      speedTrackersRef.current.delete(localId);
      const targetDeviceId = retryInfoRef.current.get(localId)?.webrtcTargetDeviceId;
      retryInfoRef.current.delete(localId);
      updateMessageByLocalId(localId, {
        _status: 'sent',
        _progress: undefined,
        _speed: undefined,
        payload: { fileName, webrtc: true, ...(fileSize != null && fileSize > 0 ? { size: fileSize } : {}) },
      });
      sendMessage({
        type: 'file',
        payload: { fileName, webrtc: true, localId, ...(fileSize != null && fileSize > 0 ? { size: fileSize } : {}), ...(targetDeviceId ? { targetDeviceId } : {}) },
        fromDeviceId: getOrCreateDeviceId(),
        ts: Date.now(),
      }).catch((e) => logger.warn(TAG, 'WebRTC sendMessage persist failed', e));
      logger.info(TAG, 'WebRTC file sent', fileName);
    };

    mgr.onFileFailed = (fileId, fileName, error) => {
      const localId = webrtcFileLocalIdMap.current.get(fileId);
      if (!localId) return;
      webrtcFileLocalIdMap.current.delete(fileId);
      webrtcFileSizeMap.current.delete(fileId);
      speedTrackersRef.current.delete(localId);
      updateMessageByLocalId(localId, { _status: 'failed', _progress: undefined, _speed: undefined });
      logger.warn(TAG, 'WebRTC file failed', fileName, error);
    };

    mgr.onStateChange = (sessionId, state) => {
      logger.info(TAG, `WebRTC session=${sessionId} state=${state}`);
    };

    return () => {
      mgr.onProgress = null;
      mgr.onFileReceived = null;
      mgr.onFileSent = null;
      mgr.onFileFailed = null;
      mgr.onStateChange = null;
    };
  }, [updateMessageByLocalId]);

  const cancelTransfer = useCallback((localId: string) => {
    const controller = activeTransfersRef.current.get(localId);
    if (controller) {
      controller.abort();
      activeTransfersRef.current.delete(localId);
      updateMessageByLocalId(localId, { _status: 'cancelled', _progress: undefined });
    }
  }, [updateMessageByLocalId]);

  const pullFileFromOffer = useCallback(async (
    pullUrl: string,
    fileName: string,
    fileSize?: number,
    opts?: { localId?: string; fromDeviceId?: string },
  ) => {
    const sem = pullSemaphoreRef.current;
    await sem.acquire();
    const localId = opts?.localId ?? generateUUID();
    const fromPeer = opts?.fromDeviceId;
    const placeholder: ChatMessage = {
      type: 'file',
      payload: { fileName, lan: true, localId },
      fromDeviceId: fromPeer ?? 'system',
      ts: Date.now(),
      _localId: localId,
      _status: 'downloading',
      _progress: 0,
    };
    setMessages((prev) => {
      const idx = prev.findIndex((m) => rowMatchesLocalId(m, localId));
      if (idx < 0) return [...prev, placeholder];
      const cur = prev[idx] as ChatMessage;
      const curPl =
        cur.payload && typeof cur.payload === 'object' ? (cur.payload as Record<string, unknown>) : {};
      const mergedPayload = {
        ...curPl,
        fileName: (curPl.fileName as string | undefined) ?? fileName,
        lan: true,
        localId,
      };
      const next = [...prev];
      next[idx] = {
        ...cur,
        type: 'file',
        payload: mergedPayload,
        fromDeviceId: fromPeer ?? cur.fromDeviceId,
        _localId: localId,
        _status: 'downloading',
        _progress: 0,
      };
      return next;
    });
    const pullTracker = new SpeedTracker();
    speedTrackersRef.current.set(localId, pullTracker);

    try {
      const pullAbort = new AbortController();
      const pullTimer = window.setTimeout(() => pullAbort.abort(), 3_600_000);
      const resp = await fetch(pullUrl, { signal: pullAbort.signal }).finally(() =>
        clearTimeout(pullTimer),
      );
      if (!resp.ok) throw new Error(`Server returned ${resp.status}`);

      const respFileName = resp.headers.get('X-File-Name');
      const name = respFileName ? decodeURIComponent(respFileName) : fileName;
      const totalSize = parseInt(resp.headers.get('X-File-Size') ?? '0', 10) || fileSize || 0;

      const reader = resp.body?.getReader();
      if (!reader) throw new Error('No response body');

      const parts: ArrayBuffer[] = [];
      let received = 0;

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        parts.push(value.buffer.slice(value.byteOffset, value.byteOffset + value.byteLength) as ArrayBuffer);
        received += value.byteLength;
        if (totalSize > 0) {
          pullTracker.update(received);
          const pct = Math.min(Math.round((received / totalSize) * 100), 100);
          updateMessageByLocalId(localId, { _progress: pct, _speed: pullTracker.formatted });
        }
      }

      speedTrackersRef.current.delete(localId);
      if (parts.length === 0) {
        updateMessageByLocalId(localId, { _status: 'failed', _progress: undefined, _speed: undefined });
        return;
      }
      const blob = new Blob(parts, { type: 'application/octet-stream' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = name || 'download';
      a.click();
      URL.revokeObjectURL(url);

      updateMessageByLocalId(localId, {
        _status: 'sent',
        _progress: undefined,
        _speed: undefined,
        payload: { fileName: name, lan: true, localId },
      });
      logger.info(TAG, 'pullFileFromOffer downloaded', name);
    } catch (e) {
      const msg = e instanceof Error ? e.message : t('chat.pullFailed');
      logger.warn(TAG, 'pullFileFromOffer failed', msg, 'pullUrl=', pullUrl);
      speedTrackersRef.current.delete(localId);
      updateMessageByLocalId(localId, { _status: 'failed', _progress: undefined });
    } finally {
      sem.release();
    }
  }, [updateMessageByLocalId, t]);

  const handlePullProbe = useCallback(async (probeUrl: string, probeId: string) => {
    const success = await probeHttpWeb(probeUrl, 3000);
    logger.info(TAG, 'handlePullProbe probeId=', probeId, 'success=', success);
    try {
      await sendMessage({
        type: 'lan_pull_probe_result',
        payload: { probeId, success },
        fromDeviceId: getOrCreateDeviceId(),
        ts: Date.now(),
      });
    } catch (e) {
      logger.warn(TAG, 'handlePullProbe sendResult failed', e);
    }
  }, []);

  const sendWebRTCProbe = useCallback(async (targetDeviceId: string): Promise<boolean> => {
    const probeId = generateUUID();
    logger.info(TAG, 'sendWebRTCProbe probeId=', probeId, 'target=', targetDeviceId);
    return new Promise<boolean>((resolve) => {
      const timer = setTimeout(() => {
        logger.warn(TAG, 'sendWebRTCProbe timeout probeId=', probeId);
        pendingWebRTCProbesRef.current.delete(probeId);
        resolve(false);
      }, 8000);
      pendingWebRTCProbesRef.current.set(probeId, (success) => {
        logger.info(TAG, 'sendWebRTCProbe resolved probeId=', probeId, 'success=', success);
        clearTimeout(timer);
        pendingWebRTCProbesRef.current.delete(probeId);
        resolve(success);
      });
      sendMessage({
        type: 'webrtc_probe',
        payload: { probeId, targetDeviceId },
        fromDeviceId: getOrCreateDeviceId(),
        ts: Date.now(),
      }).catch((e) => {
        logger.warn(TAG, 'sendWebRTCProbe sendMessage failed:', e);
        clearTimeout(timer);
        pendingWebRTCProbesRef.current.delete(probeId);
        resolve(false);
      });
    });
  }, []);

  const sendLanHttpProbe = useCallback(async (targetDeviceId: string): Promise<{ success: boolean; lanHttpUrl?: string; senderReachable?: boolean }> => {
    const probeId = generateUUID();
    const myId = getOrCreateDeviceId();
    const selfLanUrl = devices.find((d) => d.deviceId === myId)?.lanHttpUrl ?? null;
    logger.info(TAG, 'sendLanHttpProbe probeId=', probeId, 'target=', targetDeviceId);
    return new Promise((resolve) => {
      const timer = setTimeout(() => {
        logger.warn(TAG, 'sendLanHttpProbe timeout probeId=', probeId);
        pendingLanHttpProbesRef.current.delete(probeId);
        resolve({ success: false });
      }, 5000);
      pendingLanHttpProbesRef.current.set(probeId, (result) => {
        clearTimeout(timer);
        pendingLanHttpProbesRef.current.delete(probeId);
        resolve(result);
      });
      sendMessage({
        type: 'lan_http_probe',
        payload: { probeId, targetDeviceId, senderLanHttpUrl: selfLanUrl },
        fromDeviceId: myId,
        ts: Date.now(),
      }).catch((e) => {
        logger.warn(TAG, 'sendLanHttpProbe sendMessage failed:', e);
        clearTimeout(timer);
        pendingLanHttpProbesRef.current.delete(probeId);
        resolve({ success: false });
      });
    });
  }, [devices]);

  const handleWebRTCSignal = useCallback((data: MessageEnvelope) => {
    const signal = data.payload as WebRTCSignal;
    if (!signal || !signal.sessionId) return;

    if (!window.isSecureContext) {
      logger.warn(TAG, 'WebRTC signal ignored: non-secure context (HTTP), cannot establish peer connection');
      return;
    }

    const mgr = webrtcManagerRef.current;
    if (!mgr) return;

    if (signal.type === 'webrtc_offer' && signal.senderDeviceId !== getOrCreateDeviceId() && signal.targetDeviceId === getOrCreateDeviceId()) {
      for (const fileMeta of signal.files) {
        const localId = generateUUID();
        webrtcFileLocalIdMap.current.set(fileMeta.fileId, localId);
        if (fileMeta.fileSize > 0) webrtcFileSizeMap.current.set(fileMeta.fileId, fileMeta.fileSize);
        speedTrackersRef.current.set(localId, new SpeedTracker());
        const placeholder: ChatMessage = {
          type: 'file',
          payload: { fileName: fileMeta.fileName, size: fileMeta.fileSize, webrtc: true },
          fromDeviceId: data.fromDeviceId,
          ts: Date.now(),
          _localId: localId,
          _status: 'downloading',
          _progress: 0,
        };
        setMessages((prev) => [...prev, placeholder]);
      }
    }
    mgr.handleSignal(signal);
  }, []);

  const onMessage = useCallback(
    (data: MessageEnvelope) => {
      logger.debug(TAG, 'onMessage type=', data.type, 'fromDeviceId=', data.fromDeviceId);
      if (data.type === 'device_roster_patch') {
        const patch = data as MessageEnvelope & {
          action?: string;
          deviceId?: string;
          device?: DeviceDto;
        };
        if (patch.action === 'remove' && patch.deviceId) {
          setDevices((prev) => prev.filter((d) => d.deviceId !== patch.deviceId));
          return;
        }
        if (patch.action === 'upsert' && patch.device) {
          setDevices((prev) => {
            const idx = prev.findIndex((d) => d.deviceId === patch.device!.deviceId);
            if (idx < 0) return [...prev, patch.device!];
            const next = [...prev];
            next[idx] = patch.device!;
            return next;
          });
          if (patch.device.deviceId !== getOrCreateDeviceId() && patch.device.presenceStatus !== 'offline') {
            setProbeForceAll(false);
            setTargetProbeToken((x) => x + 1);
          }
          return;
        }
      }
      if (isWebRTCSignal(data)) {
        handleWebRTCSignal(data);
        return;
      }
      if (data.type === 'lan_file_offer') {
        if (data.payload && typeof data.payload === 'object') {
          const payload = data.payload as {
            pullUrl?: string;
            fileName?: string;
            size?: number;
            targetDeviceIds?: string[];
            localId?: string;
          };
          const targetIds = payload.targetDeviceIds;
          const me = getOrCreateDeviceId();
          if (Array.isArray(targetIds) && targetIds.includes(me) && payload.pullUrl) {
            pullFileFromOffer(payload.pullUrl, payload.fileName ?? t('chat.bubble.fileFallback'), payload.size, {
              localId: typeof payload.localId === 'string' ? payload.localId : undefined,
              fromDeviceId: data.fromDeviceId,
            });
          }
        }
        return;
      }
      if (data.type === 'lan_pull_probe' && data.payload && typeof data.payload === 'object') {
        const payload = data.payload as { probeUrl?: string; probeId?: string; targetDeviceId?: string };
        const me = getOrCreateDeviceId();
        if (payload.targetDeviceId === me && payload.probeUrl && payload.probeId) {
          handlePullProbe(payload.probeUrl, payload.probeId);
        }
        return;
      }
      if (data.type === 'lan_pull_probe_result') return;
      if (data.type === 'lan_http_probe' && data.payload && typeof data.payload === 'object') {
        const payload = data.payload as { probeId?: string; targetDeviceId?: string; senderLanHttpUrl?: string };
        const me = getOrCreateDeviceId();
        if (payload.targetDeviceId === me && payload.probeId) {
          (async () => {
            let senderReachable = false;
            if (payload.senderLanHttpUrl) {
              senderReachable = await probeHttpWeb(payload.senderLanHttpUrl, 3000);
            }
            sendMessage({
              type: 'lan_http_probe_result',
              payload: { probeId: payload.probeId, success: true, lanHttpUrl: null, senderReachable },
              fromDeviceId: me,
              ts: Date.now(),
            }).catch(e => logger.warn(TAG, 'lan_http_probe reply failed:', e));
          })();
        }
        return;
      }
      if (data.type === 'lan_http_probe_result' && data.payload && typeof data.payload === 'object') {
        const payload = data.payload as { probeId?: string; success?: boolean; lanHttpUrl?: string; senderReachable?: boolean };
        if (payload?.probeId) {
          const resolve = pendingLanHttpProbesRef.current.get(payload.probeId);
          if (resolve) resolve({
            success: payload.success === true,
            lanHttpUrl: payload.lanHttpUrl ?? undefined,
            senderReachable: payload.senderReachable === true,
          });
        }
        return;
      }
      if (data.type === 'webrtc_probe' && data.payload && typeof data.payload === 'object') {
        const payload = data.payload as { probeId?: string; targetDeviceId?: string };
        const me = getOrCreateDeviceId();
        logger.info(TAG, 'webrtc_probe received probeId=', payload.probeId, 'target=', payload.targetDeviceId, 'me=', me, 'match=', payload.targetDeviceId === me);
        if (payload.targetDeviceId === me && payload.probeId) {
          sendMessage({
            type: 'webrtc_probe_result',
            payload: { probeId: payload.probeId, success: true, connectivity: 'online' },
            fromDeviceId: me,
            ts: Date.now(),
          }).then(() => logger.info(TAG, 'webrtc_probe reply sent probeId=', payload.probeId))
            .catch(e => logger.warn(TAG, 'webrtc_probe reply failed:', e));
        }
        return;
      }
      if (data.type === 'webrtc_probe_result') {
        const payload = data.payload as { probeId?: string; success?: boolean };
        const hasPending = payload?.probeId ? pendingWebRTCProbesRef.current.has(payload.probeId) : false;
        logger.info(TAG, 'webrtc_probe_result received probeId=', payload?.probeId, 'success=', payload?.success, 'hasPending=', hasPending);
        if (payload?.probeId) {
          const resolve = pendingWebRTCProbesRef.current.get(payload.probeId);
          if (resolve) resolve(payload.success === true);
        }
        return;
      }
      const rawPayload = data.payload && typeof data.payload === 'object' ? (data.payload as { localId?: unknown }) : null;
      const incomingLocalId = rawPayload ? normalizeMessageLocalId(rawPayload.localId) : undefined;
      if (incomingLocalId) {
        const pl = data.payload as { webrtc?: boolean; lan?: boolean; fileName?: string; targetDeviceId?: string; targetDeviceIds?: string[] };
        const me = getOrCreateDeviceId();
        if (pl.lan && Array.isArray(pl.targetDeviceIds) && !pl.targetDeviceIds.includes(me)) {
          return;
        }
        if (pl.webrtc && pl.targetDeviceId && pl.targetDeviceId !== me) {
          return;
        }
        // Merge with the local LAN/WebRTC placeholder by per-transfer
        // localId (the only stable id). Never merge by fileName — that
        // collapsed re-sent same-named files into a single bubble.
        setMessages((prev) => {
          const idx = prev.findIndex((m) => rowMatchesLocalId(m, incomingLocalId));
          if (idx >= 0) {
            const updated = [...prev];
            updated[idx] = { ...data, _localId: incomingLocalId, _status: 'sent' } as ChatMessage;
            return updated;
          }
          return [...prev, { ...data, _localId: incomingLocalId, _status: 'sent' } as ChatMessage];
        });
        return;
      }
      setMessages((prev) => [...prev, data as ChatMessage]);
    },
    [pullFileFromOffer, handlePullProbe, handleWebRTCSignal, t]
  );

  const centrifugeLifecycle = useMemo(
    () => ({
      onConnected: () => {
        registerDevice(getOrCreateDeviceId(), getDeviceName(), {
          platform: 'web',
          sessionId: presenceSessionId,
        }).catch((e) => logger.warn(TAG, 'registerDevice onConnected', e));
      },
    }),
    [presenceSessionId]
  );
  const centrifugeConnectData = useMemo(
    () => ({
      deviceId: getOrCreateDeviceId(),
      name: getDeviceName(),
      platform: 'web',
      sessionId: presenceSessionId,
    }),
    [presenceSessionId],
  );
  const { connected } = useCentrifuge(!!userId, onMessage, centrifugeLifecycle, centrifugeConnectData);

  useEffect(() => {
    onConnectedChange?.(connected);
  }, [connected, onConnectedChange]);

  const isMd = useMinWidthMd();
  const currentDeviceId = getOrCreateDeviceId();
  const otherDevices = useMemo(
    () => devices.filter((d) => d.deviceId !== currentDeviceId),
    [devices, currentDeviceId],
  );
  const lanDevices = useMemo(
    () => otherDevices.filter((d) => d.platform !== 'web'),
    [otherDevices],
  );

  const { deviceReach, freshLanUrlsRef, probing: targetsProbing } = useSendTargetProbes(
    otherDevices,
    lanDevices,
    connected,
    targetProbeToken,
    probeForceAll,
    sendWebRTCProbe,
    sendLanHttpProbe,
    async () => false,
  );
  const reachMap: Record<string, ReachStatus> = {};
  for (const [k, v] of Object.entries(deviceReach)) {
    reachMap[k] = getReachDisplayStatus(v);
  }
  const webrtcReach = reachMap;
  const lanReach = reachMap;

  useEffect(() => {
    if (storageHydratedRef.current) return;
    storageHydratedRef.current = true;
    let mode = loadSendMode();
    if (mode === 'webrtc' && typeof window !== 'undefined' && !window.isSecureContext) {
      mode = 'lan';
      persistSendMode('lan');
    }
    setSendMode(mode);
    setSelectedTargets(loadSelectedTargets());
    setDesktopPanelVisible(loadDesktopPanelOpen());
  }, []);

  const toggleDevicePanel = useCallback(() => {
    if (isMd) {
      setDesktopPanelVisible((v) => {
        const next = !v;
        persistDesktopPanelOpen(next);
        return next;
      });
    } else {
      setMobilePanelOpen((v) => !v);
    }
  }, [isMd]);

  const expandDevicePanelForHint = useCallback(() => {
    if (isMd) {
      setDesktopPanelVisible(true);
      persistDesktopPanelOpen(true);
    } else {
      setMobilePanelOpen(true);
    }
  }, [isMd]);

  const onSendModeChange = useCallback((m: WebSendMode) => {
    if (m === 'webrtc' && typeof window !== 'undefined' && !window.isSecureContext) return;
    setSendMode(m);
    persistSendMode(m);
  }, []);

  const toggleTarget = useCallback((deviceId: string) => {
    setSelectedTargets((prev) => {
      const next = new Set(prev);
      if (next.has(deviceId)) next.delete(deviceId);
      else next.add(deviceId);
      persistSelectedTargets(next);
      return next;
    });
  }, []);

  const buildFreshLanDevices = useCallback(
    (lanSelectedIds: Set<string>) => {
      return lanDevices
        .filter((d) => lanSelectedIds.has(d.deviceId))
        .map((d) => {
          const freshUrl = freshLanUrlsRef.current[d.deviceId];
          return freshUrl ? { ...d, lanHttpUrl: freshUrl } : d;
        })
        .filter((d) => d.lanHttpUrl);
    },
    [lanDevices, freshLanUrlsRef],
  );

  const onlineTargetCount = useMemo(() => {
    if (sendMode === 's3') return 0;
    if (sendMode === 'webrtc') {
      return [...selectedTargets].filter(
        (id) =>
          otherDevices.some((d) => d.deviceId === id) && webrtcReach[id] === 'online',
      ).length;
    }
    return [...selectedTargets].filter(
      (id) => lanDevices.some((d) => d.deviceId === id) && lanReach[id] === 'online',
    ).length;
  }, [sendMode, selectedTargets, otherDevices, lanDevices, webrtcReach, lanReach]);

  const effectiveSelectedCount = useMemo(() => {
    const ids = new Set(otherDevices.map((d) => d.deviceId));
    return [...selectedTargets].filter((id) => ids.has(id)).length;
  }, [selectedTargets, otherDevices]);

  const isDevicePanelOpen =
    (isMd && desktopPanelVisible) || (!isMd && mobilePanelOpen);

  const deviceBadge = useMemo(() => {
    const hasSelected = effectiveSelectedCount > 0;
    const show = hasSelected || (!connected && otherDevices.length > 0);
    if (!show) return null;
    if (hasSelected) {
      return { className: 'bg-emerald-500 text-white', text: String(effectiveSelectedCount) };
    }
    return { className: 'bg-amber-500 text-white', text: String(otherDevices.length) };
  }, [effectiveSelectedCount, connected, otherDevices.length]);

  const webrtcAvailable = typeof window !== 'undefined' && window.isSecureContext;

  useEffect(() => {
    if (sendMode === 'webrtc' && !webrtcAvailable) {
      setSendMode('lan');
      persistSendMode('lan');
    }
  }, [sendMode, webrtcAvailable]);

  const collapseDesktopSidebar = useCallback(() => {
    setDesktopPanelVisible(false);
    persistDesktopPanelOpen(false);
  }, []);

  useEffect(() => {
    if (!userId) return;
    let cancelled = false;
    getMessageHistory(CHAT_PAGE_SIZE)
      .then((list) => {
        if (cancelled) return;
        const filtered = list.filter((m) => !EPHEMERAL_TYPES.has(m.type));
        if (list.length < CHAT_PAGE_SIZE) {
          hasNoMoreRef.current = true;
        }
        setMessages(filtered.reverse() as ChatMessage[]);
      })
      .catch((e) => logger.warn(TAG, 'loadHistory failed', e));
    transferStateManager.cleanExpired();
    return () => { cancelled = true; };
  }, [userId]);

  useEffect(() => {
    if (!userId) return;
    registerDevice(getOrCreateDeviceId(), getDeviceName(), {
      platform: 'web',
      sessionId: presenceSessionId,
    })
      .then(() => listDevices())
      .then(setDevices)
      .catch((e) => logger.warn(TAG, 'listDevices failed', e));
  }, [userId, presenceSessionId]);

  useEffect(() => {
    if (prependingRef.current) {
      prependingRef.current = false;
      requestAnimationFrame(() => {
        const el = listRef.current;
        if (!el) return;
        const distanceToBottom = el.scrollHeight - el.scrollTop - el.clientHeight;
        setShowScrollToBottom(distanceToBottom > SCROLL_TO_BOTTOM_THRESHOLD);
      });
      return;
    }
    const n = messages.length;
    const grew = n > prevMessageCountRef.current;
    prevMessageCountRef.current = n;
    if (grew) {
      listRef.current?.scrollTo(0, listRef.current.scrollHeight);
      setShowScrollToBottom(false);
    } else {
      requestAnimationFrame(() => {
        const el = listRef.current;
        if (!el) return;
        const distanceToBottom = el.scrollHeight - el.scrollTop - el.clientHeight;
        setShowScrollToBottom(distanceToBottom > SCROLL_TO_BOTTOM_THRESHOLD);
      });
    }
  }, [messages]);

  const loadMoreMessages = useCallback(async () => {
    if (loadingMoreRef.current || hasNoMoreRef.current) return;
    loadingMoreRef.current = true;
    setLoadingMore(true);
    try {
      const oldest = messages[0];
      if (!oldest) return;
      const before = (oldest as ChatMessage & { id?: number }).id;
      if (before == null) return;

      const list = await getMessageHistory(CHAT_PAGE_SIZE, before);
      const filtered = list.filter((m) => !EPHEMERAL_TYPES.has(m.type));
      if (list.length < CHAT_PAGE_SIZE) {
        hasNoMoreRef.current = true;
      }
      if (filtered.length > 0) {
        const el = listRef.current;
        const prevScrollHeight = el?.scrollHeight ?? 0;
        const prevScrollTop = el?.scrollTop ?? 0;
        prependingRef.current = true;
        setMessages((prev) => [...(filtered.reverse() as ChatMessage[]), ...prev]);
        requestAnimationFrame(() => {
          if (el) {
            el.scrollTop = el.scrollHeight - prevScrollHeight + prevScrollTop;
          }
        });
      }
    } catch (e) {
      logger.warn(TAG, 'loadMoreMessages failed', e);
    } finally {
      loadingMoreRef.current = false;
      setLoadingMore(false);
    }
  }, [messages]);

  const handleListScroll = useCallback(() => {
    const el = listRef.current;
    if (!el) return;
    const distanceToBottom = el.scrollHeight - el.scrollTop - el.clientHeight;
    setShowScrollToBottom(distanceToBottom > SCROLL_TO_BOTTOM_THRESHOLD);
    if (el.scrollTop < 80 && !loadingMoreRef.current && !hasNoMoreRef.current) {
      loadMoreMessages();
    }
  }, [loadMoreMessages]);

  const scrollToBottom = useCallback(() => {
    const el = listRef.current;
    if (!el) return;
    el.scrollTo({ top: el.scrollHeight, behavior: 'smooth' });
    setShowScrollToBottom(false);
  }, []);

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault();
    const text = input.trim();
    if (!text || sending) return;
    setInput('');
    setSending(true);
    const localId = generateUUID();
    const deviceId = getOrCreateDeviceId();
    const envelope: ChatMessage = {
      type: 'text',
      payload: { text, localId },
      fromDeviceId: deviceId,
      ts: Date.now(),
      _localId: localId,
      _status: 'sending',
    };
    setMessages((prev) => [...prev, envelope]);
    setSendError(null);
    try {
      await sendMessage({ type: envelope.type, payload: envelope.payload, fromDeviceId: envelope.fromDeviceId, ts: envelope.ts });
      updateMessageByLocalId(localId, { _status: 'sent' });
    } catch (e) {
      const msg = e instanceof Error ? e.message : t('chat.sendFailed');
      logger.warn(TAG, 'sendMessage failed', msg);
      setSendError(msg);
      updateMessageByLocalId(localId, { _status: 'failed' });
    } finally {
      setSending(false);
    }
  };

  const loadDevices = useCallback(() => {
    listDevices().then(setDevices);
  }, []);

  useEffect(() => {
    if (!userId) return;
    const deviceId = getOrCreateDeviceId();
    const markOnline = () => {
      void updateDevicePresence(deviceId, {
        sessionId: presenceSessionId,
        status: 'online',
        platform: 'web',
      }).then((dto) => {
        setDevices((prev) => {
          const idx = prev.findIndex((d) => d.deviceId === dto.deviceId);
          if (idx < 0) return [...prev, dto];
          const next = [...prev];
          next[idx] = dto;
          return next;
        });
      }).catch((e) => logger.warn(TAG, 'presence online failed', e));
    };
    const markOffline = () => {
      void updateDevicePresence(deviceId, {
        sessionId: presenceSessionId,
        status: 'offline',
        platform: 'web',
      }, { keepalive: true }).catch((e) => logger.warn(TAG, 'presence offline failed', e));
    };
    const onVisibility = () => {
      if (document.visibilityState === 'visible') {
        markOnline();
        loadDevices();
      }
    };
    window.addEventListener('pagehide', markOffline);
    document.addEventListener('visibilitychange', onVisibility);
    markOnline();
    return () => {
      document.removeEventListener('visibilitychange', onVisibility);
      window.removeEventListener('pagehide', markOffline);
      markOffline();
    };
  }, [userId, presenceSessionId, loadDevices]);

  const refreshSendTargets = useCallback(() => {
    setProbeForceAll(true);
    setTargetProbeToken((t) => t + 1);
    loadDevices();
  }, [loadDevices]);

  /** 首次进入会话且已有其他设备时探测一次（等同整页刷新后的首次加载）。 */
  const initialTargetProbeForUserRef = useRef<string | undefined>(undefined);
  useEffect(() => {
    if (!userId) {
      initialTargetProbeForUserRef.current = undefined;
      setProbeForceAll(false);
      setTargetProbeToken(0);
    }
  }, [userId]);

  useEffect(() => {
    if (!userId || !connected || otherDevices.length === 0) return;
    if (initialTargetProbeForUserRef.current === userId) return;
    initialTargetProbeForUserRef.current = userId;
    setProbeForceAll(false);
    setTargetProbeToken((t) => t + 1);
  }, [userId, connected, otherDevices.length]);

  /** 发送目标面板从关到开时刷新列表并重新探测。 */
  const devicePanelOpenPrevRef = useRef<boolean | null>(null);
  useEffect(() => {
    const prev = devicePanelOpenPrevRef.current;
    devicePanelOpenPrevRef.current = isDevicePanelOpen;
    if (prev === null) return;
    if (!userId || !connected) return;
    if (isDevicePanelOpen && prev === false) {
      refreshSendTargets();
    }
  }, [isDevicePanelOpen, userId, connected, refreshSendTargets]);

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const fileList = e.target.files;
    if (!fileList || fileList.length === 0) return;
    const files = Array.from(fileList);
    e.target.value = '';
    setFileError(null);
    setPendingFiles((prev) => [...prev, ...files]);
  };

  const removePendingFile = (index: number) => {
    setPendingFiles((prev) => prev.filter((_, i) => i !== index));
  };

  const sendSingleFile = async (file: File, useLan: boolean, targetDevices: DeviceDto[]) => {
    const localId = generateUUID();
    const deviceId = getOrCreateDeviceId();
    const abortController = new AbortController();
    activeTransfersRef.current.set(localId, abortController);

    if (useLan) {
      if (targetDevices.length === 0) {
        logger.warn(TAG, 'sendFile LAN no reachable devices', file.name);
        setFileError('chat.errors.deviceUnavailable');
        activeTransfersRef.current.delete(localId);
        return;
      }
      retryInfoRef.current.set(localId, { file, channel: 'lan', targetDevices });
      const lanPayload = { fileName: file.name, size: file.size, lan: true, targetDeviceIds: targetDevices.map((d) => d.deviceId), localId };
      const placeholder: ChatMessage = {
        type: 'file',
        payload: lanPayload,
        fromDeviceId: deviceId,
        ts: Date.now(),
        _localId: localId,
        _status: 'uploading',
        _progress: 0,
      };
      setMessages((prev) => [...prev, placeholder]);
      const lanTracker = new SpeedTracker();
      speedTrackersRef.current.set(localId, lanTracker);
      try {
        const lanOk = await trySendFileViaLan(file, targetDevices, abortController, (pct) => {
          lanTracker.update(Math.round(file.size * pct / 100));
          updateMessageByLocalId(localId, { _progress: pct, _speed: lanTracker.formatted });
        }, localId);
        if (abortController.signal.aborted) return;
        if (!lanOk) throw new Error('chat.httpSendFailed');
        await sendMessage({ type: 'file', payload: lanPayload, fromDeviceId: deviceId, ts: Date.now() });
        retryInfoRef.current.delete(localId);
        updateMessageByLocalId(localId, { _status: 'sent', _progress: undefined, _speed: undefined });
        logger.info(TAG, 'sendFile LAN ok', file.name);
      } catch (e) {
        if (e instanceof DOMException && e.name === 'AbortError') {
          updateMessageByLocalId(localId, { _status: 'cancelled', _progress: undefined, _speed: undefined });
          return;
        }
        const errMsg = e instanceof Error ? e.message : String(e);
        logger.warn(TAG, 'sendFile LAN failed', file.name, e, 'localId=', localId);
        if (
          errMsg.includes(TRANSFER_STALL_TIMEOUT_MESSAGE) ||
          errMsg.includes('停滞') ||
          errMsg.toLowerCase().includes('stall') ||
          errMsg.includes('timeout') ||
          errMsg.includes('Timeout')
        ) {
          setFileError('chat.errors.httpStall');
        }
        updateMessageByLocalId(localId, { _status: 'failed', _speed: undefined, _progress: undefined });
      } finally {
        activeTransfersRef.current.delete(localId);
        speedTrackersRef.current.delete(localId);
      }
      return;
    }

    const configured = await hasS3Config();
    if (!configured) {
      logger.warn(TAG, 'sendFile hasS3Config=false');
      setFileError('chat.errors.configureS3First');
      activeTransfersRef.current.delete(localId);
      return;
    }
    retryInfoRef.current.set(localId, { file, channel: 's3', targetDevices: [] });
    const placeholder: ChatMessage = {
      type: 'file',
      payload: { fileName: file.name, size: file.size, localId },
      fromDeviceId: deviceId,
      ts: Date.now(),
      _localId: localId,
      _status: 'uploading',
      _progress: 0,
    };
    setMessages((prev) => [...prev, placeholder]);
    logger.info(TAG, 'sendFile S3 start', file.name, 'size=', file.size);
    const s3Tracker = new SpeedTracker();
    speedTrackersRef.current.set(localId, s3Tracker);
    let lastLoggedPct = 0;
    try {
      const result = await cloudTransfer.upload(
        file,
        (sent, total) => {
          s3Tracker.update(sent);
          const pct = total > 0 ? Math.min(Math.round((sent / total) * 100), 100) : 0;
          updateMessageByLocalId(localId, { _progress: pct, _speed: s3Tracker.formatted });
          if (pct >= lastLoggedPct + 10 || pct === 100) {
            lastLoggedPct = pct;
            logger.info(TAG, 'S3 upload progress', file.name, `${pct}%`);
          }
        },
        abortController.signal,
      );
      await sendMessage({
        type: 'file',
        payload: { key: result.key, fileName: file.name, size: file.size, localId },
        fromDeviceId: deviceId,
        ts: Date.now(),
      });
      retryInfoRef.current.delete(localId);
      updateMessageByLocalId(localId, { _status: 'sent', _progress: undefined, _speed: undefined, payload: { key: result.key, fileName: file.name, size: file.size, localId } });
      logger.info(TAG, 'sendFile S3 ok', file.name, 'key=', result.key);
    } catch (e) {
      if (e instanceof DOMException && e.name === 'AbortError') {
        updateMessageByLocalId(localId, { _status: 'cancelled', _progress: undefined, _speed: undefined });
        return;
      }
      logger.warn(TAG, 'sendFile S3 failed', file.name, e);
      setFileError(e instanceof Error ? e.message : 'chat.sendFailed');
      updateMessageByLocalId(localId, { _status: 'failed', _speed: undefined });
    } finally {
      activeTransfersRef.current.delete(localId);
      speedTrackersRef.current.delete(localId);
    }
  };

  const sendFilesViaWebRTC = async (files: File[], targetDeviceId: string) => {
    const mgr = webrtcManagerRef.current;
    if (!mgr) return;

    const deviceId = getOrCreateDeviceId();
    const pendingWithMeta = files.map((file) => {
      const fileId = generateUUID();
      // Sender's per-transfer localId is mirrored into the WebRTC meta so the
      // receiver can dedup the eventual Centrifugo `file` publication by
      // localId (not fileName) against its local receiver bubble.
      const localId = generateUUID();
      const meta: FileMetadata = {
        fileId,
        fileName: file.name,
        fileSize: file.size,
        mimeType: file.type || 'application/octet-stream',
        senderLocalId: localId,
      };
      return { file, meta, localId };
    });

    for (const { file, meta, localId } of pendingWithMeta) {
      webrtcFileLocalIdMap.current.set(meta.fileId, localId);
      if (meta.fileSize > 0) webrtcFileSizeMap.current.set(meta.fileId, meta.fileSize);
      retryInfoRef.current.set(localId, { file, channel: 'webrtc', targetDevices: [], webrtcTargetDeviceId: targetDeviceId });
      const tracker = new SpeedTracker();
      speedTrackersRef.current.set(localId, tracker);

      const placeholder: ChatMessage = {
        type: 'file',
        payload: { fileName: meta.fileName, size: meta.fileSize, webrtc: true, localId },
        fromDeviceId: deviceId,
        ts: Date.now(),
        _localId: localId,
        _status: 'uploading',
        _progress: 0,
      };
      setMessages((prev) => [...prev, placeholder]);
    }

    try {
      const session = await mgr.initiateTransfer(targetDeviceId, pendingWithMeta);
      await session.connected;
      logger.info(TAG, 'WebRTC transfer initiated to', targetDeviceId);
      await session.sendsFinished;
    } catch (err) {
      const s3Ok = await hasS3Config().catch(() => false);
      if (s3Ok) {
        logger.warn(TAG, 'WebRTC failed, fallback to S3', err);
        await runWithConcurrency(pendingWithMeta, MAX_PARALLEL_FILE_SENDS, async ({ file, meta }) => {
          const localId = webrtcFileLocalIdMap.current.get(meta.fileId);
          if (localId) {
            webrtcFileLocalIdMap.current.delete(meta.fileId);
            webrtcFileSizeMap.current.delete(meta.fileId);
            speedTrackersRef.current.delete(localId);
            updateMessageByLocalId(localId, {
              _status: 'uploading',
              _progress: 0,
              _speed: undefined,
              payload: { fileName: file.name, size: file.size },
            });
          }
          await sendSingleFile(file, false, []);
        });
      } else {
        logger.warn(TAG, 'WebRTC failed, no S3 fallback', err);
        setFileError('chat.errors.webrtcTryHttp');
        for (const { meta } of pendingWithMeta) {
          const localId = webrtcFileLocalIdMap.current.get(meta.fileId);
          if (localId) {
            webrtcFileLocalIdMap.current.delete(meta.fileId);
            webrtcFileSizeMap.current.delete(meta.fileId);
            speedTrackersRef.current.delete(localId);
            updateMessageByLocalId(localId, { _status: 'failed', _progress: undefined, _speed: undefined });
          }
        }
      }
    }
  };

  useEffect(() => {
    sendSingleFileRef.current = sendSingleFile;
    sendFilesViaWebRTCRef.current = sendFilesViaWebRTC;
  });

  const handleRetryText = useCallback(
    (localId: string) => {
      const msg = messages.find((m) => m._localId === localId && m.type === 'text');
      if (!msg || msg._status !== 'failed') return;
      const text = (msg.payload as { text?: string })?.text;
      if (!text) return;
      updateMessageByLocalId(localId, { _status: 'sending' });
      sendMessage({ type: 'text', payload: msg.payload, fromDeviceId: msg.fromDeviceId, ts: Date.now() })
        .then(() => updateMessageByLocalId(localId, { _status: 'sent' }))
        .catch((e) => {
          logger.warn(TAG, 'sendMessage retry failed', e);
          updateMessageByLocalId(localId, { _status: 'failed' });
        });
    },
    [messages, updateMessageByLocalId],
  );

  const handleRetryFile = useCallback((localId: string) => {
    const info = retryInfoRef.current.get(localId);
    if (!info) return;
    retryInfoRef.current.delete(localId);
    setMessages((prev) => prev.filter((m) => m._localId !== localId));

    switch (info.channel) {
      case 'lan':
        void sendSingleFileRef.current(info.file, true, info.targetDevices);
        break;
      case 'webrtc':
        if (info.webrtcTargetDeviceId) {
          void sendFilesViaWebRTCRef.current([info.file], info.webrtcTargetDeviceId);
        } else {
          setFileError('chat.errors.webrtcRetryHttp');
        }
        break;
      default:
        void sendSingleFileRef.current(info.file, false, []);
    }
  }, []);

  const tryResolveLanUrl = useCallback(async (device: DeviceDto): Promise<string | null> => {
    const baseUrl = device.lanHttpUrl;
    if (!baseUrl) return null;
    let parsed: URL;
    try {
      parsed = new URL(baseUrl);
    } catch {
      return null;
    }

    // First try the current URL with two timeouts.
    if (await probeHttpWeb(baseUrl, 1500)) return baseUrl;
    if (await probeHttpWeb(baseUrl, 3000)) return baseUrl;

    // Flutter receiver binds ports in [9080, 9100]. If cloud has stale port,
    // discover the real listening port on the same host.
    const currentPort = parsed.port ? Number(parsed.port) : (parsed.protocol === 'https:' ? 443 : 80);
    const scanPorts: number[] = [];
    for (let p = 9080; p <= 9100; p++) {
      if (p !== currentPort) scanPorts.push(p);
    }

    const candidates = scanPorts.map((p) => `${parsed.protocol}//${parsed.hostname}:${p}`);
    const found = await Promise.all(
      candidates.map(async (url) => ({ url, ok: await probeHttpWeb(url, 900) })),
    );
    const hit = found.find((x) => x.ok);
    return hit?.url ?? null;
  }, []);

  const verifyLanTargets = useCallback(async (targets: DeviceDto[]): Promise<DeviceDto[]> => {
    if (targets.length === 0) return [];
    const results: Array<DeviceDto | null> = await Promise.all(
      targets.map(async (d) => {
        const resolvedUrl = await tryResolveLanUrl(d);
        if (!resolvedUrl) return null;
        if (resolvedUrl !== d.lanHttpUrl) {
          // Best-effort persist corrected URL to reduce future stale hits.
          try {
            await updateDevice(d.deviceId, { lanHttpUrl: resolvedUrl });
          } catch (e) {
            logger.warn(TAG, 'updateDevice lanHttpUrl failed:', d.deviceId, e);
          }
        }
        return { ...d, lanHttpUrl: resolvedUrl } as DeviceDto;
      }),
    );
    return results.filter((d): d is DeviceDto => d !== null);
  }, [tryResolveLanUrl]);

  const sendFileToTargets = async (mode: 'webrtc' | 'lan' | 's3', selectedIds?: Set<string>, freshDevices?: DeviceDto[]) => {
    const filesToSend = [...pendingFiles];
    setPendingFiles([]);
    setFileError(null);
    if (filesToSend.length === 0) return;

    logger.info(TAG, 'send batch start', { mode, fileCount: filesToSend.length });

    if (mode === 'webrtc' && selectedIds) {
      const targetIds = Array.from(selectedIds);
      await runWithConcurrency(targetIds, MAX_PARALLEL_WEBRTC_TARGETS, async (targetId) => {
        await sendFilesViaWebRTC(filesToSend, targetId);
      });
      return;
    }

    const useLan = mode === 'lan';
    const selectedLanTargets = useLan
      ? (freshDevices && freshDevices.length > 0
          ? freshDevices
          : (selectedIds ? devices.filter((d) => selectedIds.has(d.deviceId) && d.lanHttpUrl) : []))
      : [];
    const targetDevices = useLan
      ? await verifyLanTargets(selectedLanTargets)
      : [];

    if (useLan && targetDevices.length === 0) {
      // Keep transfer available even when precheck is inconclusive.
      // Some devices may fail /probe transiently but still accept /transfer.
      logger.warn(TAG, 'LAN precheck failed for all targets, fallback to direct send');
      setFileError('chat.errors.preflightPartial');
      await runWithConcurrency(filesToSend, MAX_PARALLEL_FILE_SENDS, async (file) => {
        await sendSingleFile(file, true, selectedLanTargets);
      });
      return;
    }
    if (useLan && targetDevices.length < selectedLanTargets.length) {
      setFileError('chat.errors.skippedUnreachable');
    }

    await runWithConcurrency(filesToSend, MAX_PARALLEL_FILE_SENDS, async (file) => {
      await sendSingleFile(file, useLan, targetDevices);
    });
  };

  const confirmSendFromModal = () => {
    if (sendMode === 'webrtc') {
      const ids = new Set(
        [...selectedTargets].filter(
          (id) =>
            otherDevices.some((d) => d.deviceId === id) && webrtcReach[id] === 'online',
        ),
      );
      void sendFileToTargets('webrtc', ids);
      return;
    }
    if (sendMode === 'lan') {
      const ids = new Set(
        [...selectedTargets].filter(
          (id) =>
            lanDevices.some((d) => d.deviceId === id) && lanReach[id] === 'online',
        ),
      );
      void sendFileToTargets('lan', ids, buildFreshLanDevices(ids));
      return;
    }
    void sendFileToTargets('s3');
  };

  const handleSendFiles = () => {
    if (pendingFiles.length === 0) return;
    if (sendMode === 'webrtc' && !webrtcAvailable) {
      setFileError('chat.errors.webrtcNotSupported');
      expandDevicePanelForHint();
      return;
    }
    if (sendMode !== 's3' && onlineTargetCount === 0) {
      setFileError('chat.errors.selectOnlineTargets');
      expandDevicePanelForHint();
      return;
    }
    void confirmSendFromModal();
  };

  const handleDeleteMessage = async (msg: ChatMessage) => {
    const msgId = msg.id;
    if (msgId != null) {
      try {
        await deleteMessage(msgId);
      } catch {
        logger.warn(TAG, 'deleteMessage failed', msgId);
      }
    }
    setMessages((prev) => prev.filter((m) =>
      msg._localId ? m._localId !== msg._localId : m !== msg
    ));
  };

  const toggleMessageSelect = useCallback((key: string) => {
    setSelectedKeys((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  }, []);

  const exitSelectMode = useCallback(() => {
    setSelectMode(false);
    setSelectedKeys(new Set());
  }, []);

  const toggleSelectAllMessages = useCallback(() => {
    setSelectedKeys((prev) => {
      const allKeys = messages.map(getMessageSelectKey).filter(Boolean) as string[];
      const allSelected = allKeys.length > 0 && allKeys.every((k) => prev.has(k));
      if (allSelected) return new Set();
      return new Set(allKeys);
    });
  }, [messages]);

  const enterSelectWithKey = useCallback((key: string) => {
    setSelectMode(true);
    setSelectedKeys(new Set([key]));
  }, []);

  const handleBulkDelete = useCallback(async () => {
    if (selectedKeys.size === 0) return;
    if (!window.confirm(t('chat.confirmBulkDelete', { count: selectedKeys.size }))) return;
    const keys = selectedKeys;
    for (const msg of messages) {
      const k = getMessageSelectKey(msg);
      if (!k || !keys.has(k)) continue;
      if (msg.id != null) {
        try {
          await deleteMessage(msg.id);
        } catch {
          logger.warn(TAG, 'bulk deleteMessage failed', msg.id);
        }
      }
    }
    setMessages((prev) =>
      prev.filter((m) => {
        const k = getMessageSelectKey(m);
        return !k || !keys.has(k);
      }),
    );
    exitSelectMode();
  }, [messages, selectedKeys, exitSelectMode, t]);

  useEffect(() => {
    if (!selectMode) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') exitSelectMode();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [selectMode, exitSelectMode]);

  useEffect(() => {
    if (!onSelectionChromeChange) return;
    if (!selectMode) {
      onSelectionChromeChange(null);
      return;
    }
    const allKeys = messages.map(getMessageSelectKey).filter(Boolean) as string[];
    const selectableCount = allKeys.length;
    const allSelected = selectableCount > 0 && allKeys.every((k) => selectedKeys.has(k));
    onSelectionChromeChange({
      selectedCount: selectedKeys.size,
      allSelected,
      onExit: exitSelectMode,
      onToggleSelectAll: toggleSelectAllMessages,
      onBulkDelete: handleBulkDelete,
    });
  }, [
    selectMode,
    selectedKeys,
    messages,
    onSelectionChromeChange,
    exitSelectMode,
    toggleSelectAllMessages,
    handleBulkDelete,
  ]);

  const selectionChromeRef = useRef(onSelectionChromeChange);
  selectionChromeRef.current = onSelectionChromeChange;
  useEffect(() => () => selectionChromeRef.current?.(null), []);

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
  }, []);

  return (
    <div
      className="h-full flex flex-row min-h-0"
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
    >
      {isMd && desktopPanelVisible && (
        <aside className="flex h-full min-h-0 w-[220px] shrink-0 flex-col overflow-hidden border-r border-border/60 bg-background">
          <DeviceSendPanel
            devices={devices}
            currentDeviceId={currentDeviceId}
            sendMode={sendMode}
            onSendModeChange={onSendModeChange}
            selectedTargets={selectedTargets}
            onToggleTarget={toggleTarget}
            webrtcReach={webrtcReach}
            lanReach={lanReach}
            onRefreshTargets={refreshSendTargets}
            targetsProbing={targetsProbing}
            showCollapseButton
            onCollapseSidebar={collapseDesktopSidebar}
          />
        </aside>
      )}
      {!isMd && mobilePanelOpen && (
        <>
          <button
            type="button"
            className="fixed inset-0 z-40 cursor-default border-0 bg-black/45 p-0 backdrop-blur-[2px] dark:bg-black/55"
            aria-label={t('chat.closeSendPanel')}
            onClick={() => setMobilePanelOpen(false)}
          />
          <div className="fixed bottom-0 left-0 top-0 z-50 flex min-h-0 w-[min(90vw,280px)] max-w-[320px] flex-col border-r border-border/70 bg-background shadow-xl">
            <div className="flex shrink-0 justify-end border-b border-border/50 bg-muted/20 px-2 py-1.5">
              <Button type="button" variant="ghost" size="sm" onClick={() => setMobilePanelOpen(false)}>
                {t('chat.sendBarDone')}
              </Button>
            </div>
            <div className="flex-1 min-h-0 overflow-hidden">
              <DeviceSendPanel
                devices={devices}
                currentDeviceId={currentDeviceId}
                sendMode={sendMode}
                onSendModeChange={onSendModeChange}
                selectedTargets={selectedTargets}
                onToggleTarget={toggleTarget}
                webrtcReach={webrtcReach}
                lanReach={lanReach}
                onRefreshTargets={refreshSendTargets}
                targetsProbing={targetsProbing}
              />
            </div>
          </div>
        </>
      )}
      <div className="relative flex min-h-0 min-w-0 flex-1 flex-col bg-background">
      {isDraggingOver && (
        <div className="pointer-events-none absolute inset-0 z-50 m-2 flex items-center justify-center rounded-2xl border-2 border-dashed border-primary/55 bg-background/78 backdrop-blur-sm">
          <p className="font-display text-sm tracking-tight text-muted-foreground">{t('chat.dragLabel')}</p>
        </div>
      )}
      {/* Message list */}
      <div ref={listRef} className="flex-1 space-y-4 overflow-y-auto p-4 sm:p-5" onScroll={handleListScroll}>
        {loadingMore && (
          <div className="flex justify-center py-2">
            <span className="text-xs text-muted-foreground">{t('chat.loadMore')}</span>
          </div>
        )}
        {messages.length === 0 && !loadingMore && (
          <div className="flex h-full select-none flex-col items-center justify-center gap-4 px-6 text-center text-muted-foreground">
            <MessageCircle className="h-12 w-12 opacity-25 motion-safe:animate-app-fade-up" strokeWidth={1.15} />
            <p className="max-w-xs text-sm leading-relaxed motion-safe:animate-app-fade-up app-stagger-1">
              {t('chat.empty.hint')}
            </p>
          </div>
        )}
        {messages.length > 0 && (
          <div className="relative w-full" style={{ height: rowVirtualizer.getTotalSize() }}>
            {rowVirtualizer.getVirtualItems().map((vi) => {
              const msg = messages[vi.index];
              if (!msg) return null;
              const selectKey = getMessageSelectKey(msg);
              const selected = selectKey != null && selectedKeys.has(selectKey);
              const transferring = isMessageTransferring(msg);
              const onEnterMultiSelect =
                selectKey && !transferring ? () => enterSelectWithKey(selectKey) : undefined;
              return (
                <div
                  key={vi.key}
                  data-index={vi.index}
                  ref={rowVirtualizer.measureElement}
                  className="absolute left-0 top-0 w-full px-0 pb-4"
                  style={{ transform: `translateY(${vi.start}px)` }}
                >
                  <div
                    className={`group -mx-1 flex items-start gap-1 rounded-xl px-1 py-0.5 transition-colors duration-150 ${
                      selectMode && selected ? 'bg-primary/12 ring-1 ring-primary/20' : ''
                    } ${selectMode && selectKey ? 'cursor-pointer hover:bg-muted/40' : ''}`}
                    onClick={(e) => {
                      if (!selectMode || !selectKey) return;
                      const tgt = e.target as HTMLElement;
                      if (tgt.closest('[data-select-checkbox], button, a, [role="button"], input, textarea, [data-no-select-toggle]')) return;
                      toggleMessageSelect(selectKey);
                    }}
                  >
                    {selectMode && selectKey && (
                      <div
                        data-select-checkbox
                        className="shrink-0 w-10 pt-0.5 flex justify-center items-start"
                        onClick={(e) => e.stopPropagation()}
                      >
                        <button
                          type="button"
                          title={selected ? t('chat.deselectToggle') : t('chat.selectToggle')}
                          className="p-0.5 rounded-full text-muted-foreground hover:text-foreground shrink-0"
                          onClick={() => toggleMessageSelect(selectKey)}
                        >
                          {selected ? (
                            <CircleCheck className="w-6 h-6 text-primary" strokeWidth={2} />
                          ) : (
                            <Circle className="w-6 h-6" strokeWidth={2} />
                          )}
                        </button>
                      </div>
                    )}
                    <div className="min-w-0 flex-1">
                      <MessageBubble
                        msg={msg}
                        senderLabel={senderDisplayLabel(msg.fromDeviceId, devices, t)}
                        isOwn={msg.fromDeviceId === getOrCreateDeviceId()}
                        selectMode={selectMode}
                        onEnterMultiSelect={onEnterMultiSelect}
                        onRetry={
                          msg._localId && msg._status === 'failed'
                            ? msg.type === 'text'
                              ? () => handleRetryText(msg._localId!)
                              : retryInfoRef.current.has(msg._localId)
                                ? () => handleRetryFile(msg._localId!)
                                : undefined
                            : undefined
                        }
                        onCancel={
                          msg._localId && (msg._status === 'uploading' || msg._status === 'downloading')
                            ? () => cancelTransfer(msg._localId!)
                            : undefined
                        }
                        onDelete={selectMode ? undefined : () => handleDeleteMessage(msg)}
                      />
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
        {showScrollToBottom && (
          <div className="sticky bottom-3 z-20 flex justify-end pointer-events-none">
            <Button
              type="button"
              size="icon"
              onClick={scrollToBottom}
              className="pointer-events-auto rounded-full shadow-lg"
              title={t('chat.scrollBottom')}
            >
              <ChevronDown className="w-5 h-5" />
            </Button>
          </div>
        )}
      </div>

      {/* Error bar */}
      {(sendError || fileError) && (
        <div className="flex shrink-0 items-center justify-between gap-2 border-t border-destructive/15 bg-destructive/10 px-4 py-2 text-sm text-destructive backdrop-blur-sm">
          <span>{formatUiMessage(sendError ?? fileError ?? '', t)}</span>
          <Button variant="link" size="sm" onClick={() => { setSendError(null); setFileError(null); }} className="text-xs h-auto p-0">{t('common.close')}</Button>
        </div>
      )}

      {/* Pending files bar */}
      {pendingFiles.length > 0 && (
        <div className="flex shrink-0 items-center gap-2 border-t border-border/60 bg-card px-4 py-2">
          <div className="flex-1 overflow-x-auto min-w-0 scrollbar-hide" style={{ scrollbarWidth: 'none' }}>
            <div className="flex gap-1.5 items-center flex-nowrap">
              {pendingFiles.slice(0, 20).map((f, i) => (
                <span
                  key={i}
                  className="inline-flex shrink-0 items-center gap-1 rounded-full border border-border/60 bg-muted/50 px-2.5 py-1 text-xs backdrop-blur-sm"
                >
                  <span className="max-w-[120px] truncate">{f.name}</span>
                  <button type="button" onClick={() => removePendingFile(i)} className="text-muted-foreground hover:text-foreground ml-0.5">&times;</button>
                </span>
              ))}
            </div>
          </div>
          <div className="flex items-center gap-1.5 shrink-0">
            <Button variant="outline" size="sm" onClick={() => setShowManageSheet(true)} className="rounded-full">
              {t('chat.managePending', { count: pendingFiles.length })}
            </Button>
            <Button size="sm" onClick={handleSendFiles} className="rounded-full">
              {t('chat.send')}
            </Button>
          </div>
        </div>
      )}

      {/* Manage pending files dialog */}
      <Dialog open={showManageSheet} onOpenChange={setShowManageSheet}>
        <DialogContent className="max-h-[60vh] flex flex-col">
          <DialogHeader>
            <DialogTitle>{t('chat.pendingFiles.dialogTitle')}</DialogTitle>
            <DialogDescription>{t('chat.pendingFiles.dialogDesc', { count: pendingFiles.length })}</DialogDescription>
          </DialogHeader>
          <div className="-mx-5 flex-1 overflow-y-auto px-5">
            {pendingFiles.map((f, i) => (
              <div key={i} className="flex items-center justify-between py-2 border-b last:border-b-0">
                <div className="min-w-0 flex-1 mr-2">
                  <p className="text-sm truncate">{f.name}</p>
                  <p className="text-xs text-muted-foreground">{(f.size / 1024).toFixed(1)} KB</p>
                </div>
                <button
                  type="button"
                  onClick={() => removePendingFile(i)}
                  className="shrink-0 text-muted-foreground hover:text-destructive p-1"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>
            ))}
          </div>
          <DialogFooter>
            <Button variant="destructive" size="sm" onClick={() => { setPendingFiles([]); setShowManageSheet(false); }}>
              {t('chat.pendingFiles.clearAll')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Input bar（对齐 Flutter _ChatComposer：设备 + 模式 + 输入 + 加号/发送） */}
      <form
        onSubmit={handleSend}
        className="shrink-0 border-t border-border/60 bg-card px-3 py-2 sm:px-4 sm:py-3"
      >
        <div className="flex gap-1 items-center">
          <input
            type="file"
            ref={fileInputRef}
            onChange={handleFileSelect}
            className="hidden"
            multiple
          />
          <Button
            type="button"
            variant="ghost"
            size="icon"
            className="relative size-10 shrink-0 rounded-lg"
            title={t('chat.input.devicePanel')}
            onClick={toggleDevicePanel}
          >
            <MonitorSmartphone
              className={cn(
                'size-[22px]',
                isDevicePanelOpen ? 'text-primary' : 'text-muted-foreground',
              )}
            />
            {deviceBadge && (
              <span
                className={cn(
                  'absolute -top-0.5 -right-0.5 min-w-4 h-4 px-0.5 rounded-full text-[10px] font-semibold leading-4 text-center',
                  deviceBadge.className,
                )}
              >
                {deviceBadge.text}
              </span>
            )}
          </Button>
          <button
            type="button"
            title={t('chat.input.devicePanel')}
            onClick={toggleDevicePanel}
            className={cn(
              'shrink-0 rounded-lg px-1.5 py-0.5 text-[10px] font-medium transition-colors',
              isDevicePanelOpen
                ? 'bg-primary/10 text-primary'
                : 'bg-muted/70 text-muted-foreground hover:bg-muted',
            )}
          >
            {sendModeLabel(sendMode)}
          </button>
          <div
            className={cn(
              'relative flex-1 min-w-0 overflow-hidden rounded-full border border-input bg-muted/50 transition-colors',
              'focus-within:border-ring focus-within:ring-2 focus-within:ring-inset focus-within:ring-ring/40',
            )}
          >
            <textarea
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
                  e.preventDefault();
                  handleSend(e);
                }
              }}
              placeholder={t('chat.input.placeholder')}
              disabled={sending}
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
                <X className="size-[1.125rem] shrink-0" strokeWidth={2.5} />
              </button>
            )}
          </div>
          {input.trim() !== '' ? (
            <Button
              type="submit"
              size="icon"
              disabled={sending}
              className="size-11 shrink-0 rounded-full bg-primary text-primary-foreground shadow-sm hover:bg-primary/90 hover:text-primary-foreground disabled:opacity-50 [&_svg]:stroke-[2.5]"
              title={t('chat.input.send')}
            >
              <Send className="size-5" />
            </Button>
          ) : (
            <Button
              type="button"
              variant="ghost"
              size="icon"
              className="size-11 shrink-0 rounded-full text-muted-foreground hover:text-foreground"
              title={t('chat.input.pickFile')}
              onClick={() => fileInputRef.current?.click()}
            >
              <CirclePlus className="size-[26px]" />
            </Button>
          )}
        </div>
      </form>
      </div>
    </div>
  );
}
