'use client';

import { createContext, useContext, useState, useCallback, useEffect, useMemo, useRef, type ReactNode } from 'react';
import { usePathname } from 'next/navigation';
import { useAuth } from '@/contexts/AuthContext';
import { useCentrifuge, type CentrifugeLifecycle } from '@/hooks/useCentrifuge';
import { useSendTargetProbes, isReachOnline, type ReachStatus, type DeviceReachEntry, type DeviceReachDetail } from '@/hooks/useSendTargetProbes';
import { listDevices, registerDevice, updateDevicePresence, sendMessage, getMessageHistory, deleteMessage, deleteThreadMessages, hasS3Config, testS3Config, updateDevice } from '@/lib/api';
import type { DeviceDto, MessageEnvelope, ChatMessage } from '@/lib/api';
import { getOrCreateDeviceId, getDeviceName, getOrCreatePresenceSessionId, generateUUID } from '@/lib/deviceId';
import { logger } from '@/lib/logger';
import {
  S3_VIRTUAL_DEVICE_ID,
  accountPartLoggedIn,
  outboundForWebChat,
  threadKeyForS3WebPersist,
  threadKeyOneToOne,
} from '@/lib/threadKey';

export { S3_VIRTUAL_DEVICE_ID };
import { trySendFileViaLan, probeHttpWeb, TRANSFER_STALL_TIMEOUT_MESSAGE } from '@/lib/fileTransfer';
import { isLikelyNetworkOrCorsError, reportCorsLikely } from '@/lib/network/corsAlert';
import { SpeedTracker } from '@/lib/speedTracker';
import { WebRTCManager, isWebRTCSignal } from '@/lib/webrtc';
import type { WebRTCSignal, FileMetadata } from '@/lib/webrtc';
import { S3TransferService } from '@/lib/services/s3Transfer';
import type { CloudTransferService } from '@/lib/services/cloudTransfer';
import { transferStateManager } from '@/lib/services/transferStateManager';
import { runWithConcurrency, AsyncSemaphore } from '@/lib/concurrency';
import {
  loadSelectedTargets,
  loadSendModeForDevice,
  persistSelectedTargets,
  persistSendModeForDevice,
  type WebSendMode,
} from '@/lib/sendTargetStorage';
import {
  buildTransferModeOptions,
  resolveSendModeAutoPreferHttp,
  resolveSendModeWithMemory,
} from '@/lib/sendModeResolution';
import { normalizeMessageLocalId, rowMatchesLocalId } from '@/lib/chatMessageDedupe';
import { useI18n } from '@/contexts/I18nContext';
import { analyticsLengthBucket, analyticsTrack } from '@/lib/analytics';
import { AnalyticsEvents } from '@/lib/analyticsEvents';
import { isWebPeer } from '@/lib/peerPlatform';
import { filePayloadTransferChannel } from '@/lib/filePayload';
import { downloadS3FileAsBrowserSave } from '@/lib/downloadS3File';
import { classifyDevice } from '@/lib/probePriority';
import {
  type ConnectionDiagnosticState,
  buildDiagnosticSummary,
  diagnosticStepOrder,
  diagnosticStepTitle,
  peerLabelForDevice,
  isPeerWebDevice,
  runConnectionDiagnostic,
} from '@/lib/connectionDiagnostic';

const TAG = 'ChatContext';
const MAX_PARALLEL_FILE_SENDS = 3;
const MAX_PARALLEL_WEBRTC_TARGETS = 2;
const cloudTransfer: CloudTransferService = new S3TransferService();
const CHAT_PAGE_SIZE = 20;
const EPHEMERAL_TYPES = new Set([
  'lan_file_offer', 'lan_pull_probe', 'lan_pull_probe_result',
  'lan_http_probe', 'lan_http_probe_result',
  'webrtc_probe', 'webrtc_probe_result',
  'webrtc_offer', 'webrtc_answer', 'webrtc_ice_candidate', 'webrtc_transfer_cancel',
]);

function isProgressOnlyPatch(patch: Partial<ChatMessage>): boolean {
  const ks = Object.keys(patch);
  if (ks.length === 0) return false;
  return ks.every((k) => k === '_progress' || k === '_speed');
}

export type ChatContextValue = {
  // Connection
  connected: boolean;

  // Devices
  devices: DeviceDto[];
  currentDeviceId: string;
  otherDevices: DeviceDto[];
  lanDevices: DeviceDto[];
  refreshDevices: () => void;

  // Selected device for conversation
  selectedDeviceId: string | null;
  setSelectedDeviceId: (id: string | null) => void;

  // Send mode & targets
  sendMode: WebSendMode;
  onSendModeChange: (m: WebSendMode) => void;
  selectedTargets: Set<string>;
  toggleTarget: (deviceId: string) => void;

  // Probes
  deviceReach: Record<string, DeviceReachEntry>;
  targetsProbing: boolean;
  refreshSendTargets: () => void;
  probeSingleDevice: (deviceId: string) => void;
  runSessionConnectionDiagnostic: (deviceId: string) => void;

  // Connection diagnostic sheet
  connectionDiagnostic: ConnectionDiagnosticState | null;
  diagnosticSheetOpen: boolean;
  setDiagnosticSheetOpen: (open: boolean) => void;

  // Messages
  messages: ChatMessage[];
  sendTextMessage: (text: string) => Promise<void>;
  sending: boolean;
  sendError: string | null;
  setSendError: (e: string | null) => void;
  fileError: string | null;
  setFileError: (e: string | null) => void;

  // File sending
  pendingFiles: File[];
  setPendingFiles: React.Dispatch<React.SetStateAction<File[]>>;
  handleSendFiles: () => void;
  handleFileSelect: (e: React.ChangeEvent<HTMLInputElement>) => void;
  removePendingFile: (index: number) => void;

  // Message management
  handleDeleteMessage: (msg: ChatMessage) => Promise<void>;
  cancelTransfer: (localId: string) => void;
  handleRetryText: (localId: string) => void;
  handleRetryFile: (localId: string) => void;

  // Message list scroll
  loadMoreMessages: () => Promise<void>;
  loadingMore: boolean;

  // Multi-select
  selectMode: boolean;
  selectedKeys: Set<string>;
  toggleMessageSelect: (key: string) => void;
  exitSelectMode: () => void;
  toggleSelectAllMessages: () => void;
  enterSelectWithKey: (key: string) => void;
  handleBulkDelete: () => Promise<void>;
  clearCurrentThreadMessages: () => Promise<void>;

  // WebRTC availability
  webrtcAvailable: boolean;

  // S3 cloud relay
  s3Configured: boolean;
  s3Online: boolean;
  s3Checking: boolean;
  checkS3Config: () => Promise<void>;

  // Best send mode for a specific device
  bestSendModeForDevice: (deviceId: string) => WebSendMode;
};

const ChatContext = createContext<ChatContextValue | null>(null);

export function useChatContext(): ChatContextValue {
  const ctx = useContext(ChatContext);
  if (!ctx) throw new Error('useChatContext must be used within ChatProvider');
  return ctx;
}

const S3_CONFIG_RETRY_DELAY_MS = 500;

export function ChatProvider({ children }: { children: ReactNode }) {
  const { userId, accessToken } = useAuth();
  const { t } = useI18n();
  const pathname = usePathname();
  const prevOnS3SettingsRef = useRef(false);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const pendingPatchesRef = useRef<Map<string, Partial<ChatMessage>>>(new Map());
  const rafFlushingRef = useRef<number | null>(null);
  const pullSemaphoreRef = useRef(new AsyncSemaphore(3));
  const sendSingleFileRef = useRef<(file: File, useLan: boolean, targetDevices: DeviceDto[]) => Promise<void>>(async () => {});
  const sendFilesViaWebRTCRef = useRef<(files: File[], targetDeviceId: string) => Promise<void>>(async () => {});

  const [devices, setDevices] = useState<DeviceDto[]>([]);
  const [sendMode, setSendMode] = useState<WebSendMode>('lan');
  const [selectedTargets, setSelectedTargets] = useState<Set<string>>(() => new Set());
  const [selectedDeviceId, setSelectedDeviceId] = useState<string | null>(null);
  const userIdRef = useRef<string | null>(null);
  const selectedDeviceIdRef = useRef<string | null>(null);
  const sendModeAutoRef = useRef(true);
  const selectedPeerReachSnapshotRef = useRef<{
    presence: string;
    lanHttpUrl: string;
  } | null>(null);
  userIdRef.current = userId;
  selectedDeviceIdRef.current = selectedDeviceId;
  const [targetProbeToken, setTargetProbeToken] = useState(0);
  const [probeForceAll, setProbeForceAll] = useState(false);
  const storageHydratedRef = useRef(false);
  const presenceSessionId = useMemo(() => getOrCreatePresenceSessionId(), []);
  const activeTransfersRef = useRef<Map<string, AbortController>>(new Map());
  const speedTrackersRef = useRef<Map<string, SpeedTracker>>(new Map());
  const webrtcManagerRef = useRef<WebRTCManager | null>(null);
  const webrtcFileLocalIdMap = useRef<Map<string, string>>(new Map());
  const webrtcFileSizeMap = useRef<Map<string, number>>(new Map());
  const pendingWebRTCProbesRef = useRef<Map<string, (success: boolean) => void>>(new Map());
  const pendingLanHttpProbesRef = useRef<Map<string, (result: { success: boolean; lanHttpUrl?: string; senderReachable?: boolean }) => void>>(new Map());
  const pendingPullProbesRef = useRef<Map<string, (success: boolean) => void>>(new Map());
  const diagnosticSessionRef = useRef(0);

  const [connectionDiagnostic, setConnectionDiagnostic] = useState<ConnectionDiagnosticState | null>(null);
  const [diagnosticSheetOpen, setDiagnosticSheetOpen] = useState(false);

  type RetryInfo = { file: File; channel: 'lan' | 's3' | 'webrtc'; targetDevices: DeviceDto[]; webrtcTargetDeviceId?: string };
  const retryInfoRef = useRef<Map<string, RetryInfo>>(new Map());
  /** Server row ids (`${ts}_${fromDeviceId}`) that already triggered realtime S3 auto-download. */
  const autoDownloadedS3Ref = useRef(new Set<string>());

  const [sending, setSending] = useState(false);
  const [sendError, setSendError] = useState<string | null>(null);
  const [fileError, setFileError] = useState<string | null>(null);
  const [pendingFiles, setPendingFiles] = useState<File[]>([]);
  const [loadingMore, setLoadingMore] = useState(false);
  const loadingMoreRef = useRef(false);
  const hasNoMoreRef = useRef(false);
  const [selectMode, setSelectMode] = useState(false);
  const [selectedKeys, setSelectedKeys] = useState<Set<string>>(() => new Set());
  const [s3Configured, setS3Configured] = useState(false);
  const [s3Online, setS3Online] = useState(false);
  const [s3Checking, setS3Checking] = useState(true);
  const checkS3SeqRef = useRef(0);
  const s3OnlineRef = useRef(false);
  s3OnlineRef.current = s3Online;

  const currentDeviceId = getOrCreateDeviceId();

  if (!webrtcManagerRef.current) {
    webrtcManagerRef.current = new WebRTCManager();
  }

  // ─── Message update helpers ───────────────────────────────────────────

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

  // ─── WebRTC Manager callbacks ─────────────────────────────────────────

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
      const uid = userIdRef.current;
      const me = getOrCreateDeviceId();
      let threadKey: string;
      let toDeviceId: string | undefined;
      if (targetDeviceId) {
        if (!uid) return;
        threadKey = threadKeyOneToOne(accountPartLoggedIn(uid), me, targetDeviceId);
        toDeviceId = targetDeviceId;
      } else {
        const peer = selectedDeviceIdRef.current;
        if (!uid || !peer) return;
        const o = outboundForWebChat(uid, peer, me);
        if (!o) return;
        threadKey = o.threadKey;
        toDeviceId = o.toDeviceId;
      }
      sendMessage({
        type: 'file',
        payload: { fileName, webrtc: true, localId, ...(fileSize != null && fileSize > 0 ? { size: fileSize } : {}), ...(targetDeviceId ? { targetDeviceId } : {}) },
        fromDeviceId: me,
        ts: Date.now(),
        threadKey,
        ...(toDeviceId != null ? { toDeviceId } : {}),
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

  // ─── Transfer helpers ─────────────────────────────────────────────────

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
      let resp: Response;
      try {
        resp = await fetch(pullUrl, { signal: pullAbort.signal }).finally(() => clearTimeout(pullTimer));
      } catch (fetchErr) {
        if (isLikelyNetworkOrCorsError(fetchErr)) {
          reportCorsLikely({ url: pullUrl, mode: 'download', channel: 'lan', cause: fetchErr });
        }
        throw fetchErr;
      }
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
        payload: { fileName: name, lan: true, ...(localId ? { localId } : {}) },
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
      await sendMessage({ type: 'lan_pull_probe_result', payload: { probeId, success }, fromDeviceId: getOrCreateDeviceId(), ts: Date.now() });
    } catch (e) {
      logger.warn(TAG, 'handlePullProbe sendResult failed', e);
    }
  }, []);

  const sendWebRTCProbe = useCallback(async (targetDeviceId: string): Promise<boolean> => {
    const probeId = generateUUID();
    return new Promise<boolean>((resolve) => {
      const timer = setTimeout(() => {
        pendingWebRTCProbesRef.current.delete(probeId);
        resolve(false);
      }, 8000);
      pendingWebRTCProbesRef.current.set(probeId, (success) => {
        clearTimeout(timer);
        pendingWebRTCProbesRef.current.delete(probeId);
        resolve(success);
      });
      sendMessage({ type: 'webrtc_probe', payload: { probeId, targetDeviceId }, fromDeviceId: getOrCreateDeviceId(), ts: Date.now() }).catch((e) => {
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
    return new Promise((resolve) => {
      const timer = setTimeout(() => {
        pendingLanHttpProbesRef.current.delete(probeId);
        resolve({ success: false });
      }, 5000);
      pendingLanHttpProbesRef.current.set(probeId, (result) => {
        clearTimeout(timer);
        pendingLanHttpProbesRef.current.delete(probeId);
        resolve(result);
      });
      sendMessage({ type: 'lan_http_probe', payload: { probeId, targetDeviceId, senderLanHttpUrl: selfLanUrl }, fromDeviceId: myId, ts: Date.now() }).catch((e) => {
        clearTimeout(timer);
        pendingLanHttpProbesRef.current.delete(probeId);
        resolve({ success: false });
      });
    });
  }, [devices]);

  const sendPullProbe = useCallback(async (targetDeviceId: string): Promise<boolean> => {
    const myId = getOrCreateDeviceId();
    const selfLanUrl = devices.find((d) => d.deviceId === myId)?.lanHttpUrl?.trim();
    if (!selfLanUrl) return false;
    const probeId = generateUUID();
    return new Promise<boolean>((resolve) => {
      const timer = setTimeout(() => {
        pendingPullProbesRef.current.delete(probeId);
        resolve(false);
      }, 8000);
      pendingPullProbesRef.current.set(probeId, (success) => {
        clearTimeout(timer);
        pendingPullProbesRef.current.delete(probeId);
        resolve(success);
      });
      sendMessage({
        type: 'lan_pull_probe',
        payload: { probeId, probeUrl: selfLanUrl, targetDeviceId },
        fromDeviceId: myId,
        ts: Date.now(),
      }).catch(() => {
        clearTimeout(timer);
        pendingPullProbesRef.current.delete(probeId);
        resolve(false);
      });
    });
  }, [devices]);

  // ─── WebRTC signal handling ───────────────────────────────────────────

  const handleWebRTCSignal = useCallback((data: MessageEnvelope) => {
    const signal = data.payload as WebRTCSignal;
    if (!signal || !signal.sessionId) return;
    if (!window.isSecureContext) return;
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

  // ─── Centrifugo message handler ───────────────────────────────────────

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
      if (data.type === 'lan_pull_probe_result' && data.payload && typeof data.payload === 'object') {
        const payload = data.payload as { probeId?: string; success?: boolean };
        if (payload?.probeId) {
          const resolve = pendingPullProbesRef.current.get(payload.probeId);
          if (resolve) resolve(payload.success === true);
        }
        return;
      }
      if (data.type === 'lan_http_probe' && data.payload && typeof data.payload === 'object') {
        const payload = data.payload as { probeId?: string; targetDeviceId?: string; senderLanHttpUrl?: string };
        const me = getOrCreateDeviceId();
        if (payload.targetDeviceId === me && payload.probeId) {
          (async () => {
            let senderReachable = false;
            if (payload.senderLanHttpUrl) {
              senderReachable = await probeHttpWeb(payload.senderLanHttpUrl, 3000);
            }
            sendMessage({ type: 'lan_http_probe_result', payload: { probeId: payload.probeId, success: true, lanHttpUrl: null, senderReachable }, fromDeviceId: me, ts: Date.now() }).catch(e => logger.warn(TAG, 'lan_http_probe reply failed:', e));
          })();
        }
        return;
      }
      if (data.type === 'lan_http_probe_result' && data.payload && typeof data.payload === 'object') {
        const payload = data.payload as { probeId?: string; success?: boolean; lanHttpUrl?: string; senderReachable?: boolean };
        if (payload?.probeId) {
          const resolve = pendingLanHttpProbesRef.current.get(payload.probeId);
          if (resolve) resolve({ success: payload.success === true, lanHttpUrl: payload.lanHttpUrl ?? undefined, senderReachable: payload.senderReachable === true });
        }
        return;
      }
      if (data.type === 'webrtc_probe' && data.payload && typeof data.payload === 'object') {
        const payload = data.payload as { probeId?: string; targetDeviceId?: string };
        const me = getOrCreateDeviceId();
        if (payload.targetDeviceId === me && payload.probeId) {
          sendMessage({ type: 'webrtc_probe_result', payload: { probeId: payload.probeId, success: true, connectivity: 'online' }, fromDeviceId: me, ts: Date.now() }).catch(e => logger.warn(TAG, 'webrtc_probe reply failed:', e));
        }
        return;
      }
      if (data.type === 'webrtc_probe_result') {
        const payload = data.payload as { probeId?: string; success?: boolean };
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
        if (pl.lan && Array.isArray(pl.targetDeviceIds) && !pl.targetDeviceIds.includes(me)) return;
        if (pl.webrtc && pl.targetDeviceId && pl.targetDeviceId !== me) return;
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
      if (data.type === 'file' && data.payload && typeof data.payload === 'object') {
        const me = getOrCreateDeviceId();
        const pl = data.payload as {
          key?: string;
          fileName?: string;
          webrtc?: boolean;
          lan?: boolean;
          targetDeviceIds?: string[];
        };
        const rowId = `${data.ts}_${data.fromDeviceId}`;
        const isIncomingS3 =
          data.fromDeviceId !== me &&
          filePayloadTransferChannel(pl) === 's3' &&
          !!pl.key;

        setMessages((prev) => [
          ...prev,
          {
            ...(data as ChatMessage),
            ...(isIncomingS3 ? { _status: 'downloading' as const, _progress: 0 } : {}),
          },
        ]);

        if (isIncomingS3 && !autoDownloadedS3Ref.current.has(rowId)) {
          autoDownloadedS3Ref.current.add(rowId);
          const displayName = pl.fileName ?? t('chat.bubble.fileFallback');
          const s3Key = pl.key!;
          void (async () => {
            try {
              await downloadS3FileAsBrowserSave(s3Key, displayName, (received, total) => {
                const pct = total > 0 ? Math.round((received / total) * 100) : 0;
                setMessages((prev) =>
                  prev.map((m) =>
                    `${m.ts}_${m.fromDeviceId}` === rowId
                      ? { ...m, _progress: pct, _status: 'downloading' }
                      : m,
                  ),
                );
              });
              setMessages((prev) =>
                prev.map((m) =>
                  `${m.ts}_${m.fromDeviceId}` === rowId
                    ? { ...m, _status: 'sent', _progress: undefined }
                    : m,
                ),
              );
            } catch (e) {
              logger.warn(TAG, 'incoming S3 auto-download failed', e);
              setMessages((prev) =>
                prev.map((m) =>
                  `${m.ts}_${m.fromDeviceId}` === rowId
                    ? { ...m, _status: 'failed', _progress: undefined }
                    : m,
                ),
              );
            }
          })();
        }
        return;
      }
      setMessages((prev) => [...prev, data as ChatMessage]);
    },
    [pullFileFromOffer, handlePullProbe, handleWebRTCSignal, t],
  );

  const loadDevices = useCallback(() => {
    listDevices().then(setDevices).catch((e) => logger.warn(TAG, 'listDevices failed', e));
  }, []);

  // ─── Centrifugo connection ────────────────────────────────────────────

  const centrifugeLifecycle = useMemo<CentrifugeLifecycle>(
    () => ({
      onConnected: () => {
        void (async () => {
          try {
            await registerDevice(getOrCreateDeviceId(), getDeviceName(), {
              platform: 'web',
              sessionId: presenceSessionId,
            });
          } catch (e) {
            logger.warn(TAG, 'registerDevice onConnected', e);
          }
          loadDevices();
        })();
      },
    }),
    [loadDevices, presenceSessionId],
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

  // ─── Device lists ─────────────────────────────────────────────────────

  const otherDevices = useMemo(
    () => devices.filter((d) => d.deviceId !== currentDeviceId),
    [devices, currentDeviceId],
  );
  const lanDevices = useMemo(
    () => otherDevices.filter((d) => d.platform !== 'web'),
    [otherDevices],
  );

  const directHttpProbe = useCallback((url: string) => probeHttpWeb(url, 3000), []);

  const { deviceReach, freshLanUrlsRef, probing: targetsProbing, probeSingleDevice, applyDeviceReach } = useSendTargetProbes(
    otherDevices,
    lanDevices,
    connected,
    targetProbeToken,
    probeForceAll,
    sendWebRTCProbe,
    sendLanHttpProbe,
    directHttpProbe,
  );

  // ─── Hydrate from localStorage ────────────────────────────────────────

  useEffect(() => {
    if (storageHydratedRef.current) return;
    storageHydratedRef.current = true;
    setSelectedTargets(loadSelectedTargets());
  }, []);

  const webrtcAvailable = typeof window !== 'undefined' && window.isSecureContext;

  const reconcileSendModeForSelection = useCallback(
    (deviceId: string): WebSendMode => {
      if (deviceId === S3_VIRTUAL_DEVICE_ID) return 's3';
      const peer = devices.find((d) => d.deviceId === deviceId);
      const peerIsWeb = isWebPeer(peer?.platform);
      const entry = deviceReach[deviceId];
      const methods = entry?.methods;
      const httpAvailable = !!(
        methods?.directHttp ||
        methods?.pullReachable ||
        methods?.peerHttpHealthy ||
        methods?.lanSignaling
      );
      const s3Available = s3Configured && s3Online;
      const options = buildTransferModeOptions({
        peerIsWeb,
        webrtcAvailable,
        httpAvailable,
        webrtcReachable: !!methods?.webrtc,
        s3Available,
      });
      if (sendModeAutoRef.current) {
        return resolveSendModeAutoPreferHttp(options);
      }
      let preferred = loadSendModeForDevice(deviceId);
      if (preferred === 'webrtc' && !webrtcAvailable) {
        preferred = s3Available ? 's3' : 'lan';
      }
      return resolveSendModeWithMemory(preferred, options);
    },
    [devices, deviceReach, webrtcAvailable, s3Configured, s3Online],
  );

  useEffect(() => {
    const deviceId = selectedDeviceIdRef.current;
    if (sendMode === 'webrtc' && !webrtcAvailable && deviceId) {
      const fallback: WebSendMode =
        s3Configured && s3Online ? 's3' : 'lan';
      setSendMode(fallback);
      if (
        deviceId !== S3_VIRTUAL_DEVICE_ID &&
        !sendModeAutoRef.current
      ) {
        persistSendModeForDevice(deviceId, fallback);
      }
    }
  }, [sendMode, webrtcAvailable, s3Configured, s3Online]);

  // ─── Send mode & target helpers ───────────────────────────────────────

  const onSendModeChange = useCallback((m: WebSendMode) => {
    if (m === 'webrtc' && typeof window !== 'undefined' && !window.isSecureContext) return;
    sendModeAutoRef.current = false;
    setSendMode(m);
    const deviceId = selectedDeviceIdRef.current;
    if (deviceId && deviceId !== S3_VIRTUAL_DEVICE_ID) {
      persistSendModeForDevice(deviceId, m);
    }
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

  // ─── Load initial data ────────────────────────────────────────────────

  useEffect(() => {
    if (!userId || !selectedDeviceId) {
      setMessages([]);
      hasNoMoreRef.current = false;
      return;
    }
    const outbound = outboundForWebChat(userId, selectedDeviceId, getOrCreateDeviceId());
    if (!outbound) return;
    let cancelled = false;
    hasNoMoreRef.current = false;
    getMessageHistory(CHAT_PAGE_SIZE, undefined, outbound.threadKey)
      .then((list) => {
        if (cancelled) return;
        const filtered = list.filter((m) => !EPHEMERAL_TYPES.has(m.type));
        if (list.length < CHAT_PAGE_SIZE) hasNoMoreRef.current = true;
        setMessages(filtered.reverse() as ChatMessage[]);
      })
      .catch((e) => logger.warn(TAG, 'loadHistory failed', e));
    transferStateManager.cleanExpired();
    return () => { cancelled = true; };
  }, [userId, selectedDeviceId]);

  useEffect(() => {
    if (!userId) {
      setDevices([]);
      return;
    }
    let cancelled = false;
    void (async () => {
      try {
        await registerDevice(getOrCreateDeviceId(), getDeviceName(), {
          platform: 'web',
          sessionId: presenceSessionId,
        });
      } catch (e) {
        logger.warn(TAG, 'registerDevice on userId', e);
      }
      if (cancelled) return;
      try {
        const list = await listDevices();
        if (!cancelled) setDevices(list);
      } catch (e) {
        logger.warn(TAG, 'listDevices failed', e);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [userId, presenceSessionId]);

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

  // Config flag + connectivity test (/api/s3/test)
  const runS3ConfigCheck = useCallback(async (seq: number) => {
    try {
      const ok = await hasS3Config();
      if (seq !== checkS3SeqRef.current) return;
      setS3Configured(ok);
      let online = false;
      if (ok && userId) {
        try {
          await testS3Config();
          online = true;
        } catch {
          online = false;
        }
      }
      if (seq !== checkS3SeqRef.current) return;
      setS3Online(online);
      return ok;
    } catch {
      if (seq !== checkS3SeqRef.current) return false;
      setS3Configured(false);
      setS3Online(false);
      return false;
    }
  }, [userId]);

  const checkS3Config = useCallback(async () => {
    const seq = ++checkS3SeqRef.current;
    setS3Checking(true);
    try {
      let ok = await runS3ConfigCheck(seq);
      if (seq !== checkS3SeqRef.current) return;
      if (!ok) {
        await new Promise((r) => setTimeout(r, S3_CONFIG_RETRY_DELAY_MS));
        if (seq !== checkS3SeqRef.current) return;
        ok = await runS3ConfigCheck(seq);
      }
    } finally {
      if (seq === checkS3SeqRef.current) {
        setS3Checking(false);
      }
    }
  }, [runS3ConfigCheck]);

  const checkS3ForDiagnostic = useCallback(async (): Promise<{ configured: boolean; online: boolean }> => {
    try {
      const configured = await hasS3Config();
      if (!configured) return { configured: false, online: false };
      if (!userId) return { configured: true, online: false };
      try {
        await testS3Config();
        return { configured: true, online: true };
      } catch {
        return { configured: true, online: false };
      }
    } catch {
      return { configured: false, online: false };
    }
  }, [userId]);

  const runSessionConnectionDiagnostic = useCallback((deviceId: string) => {
    if (!deviceId || deviceId === S3_VIRTUAL_DEVICE_ID) {
      void checkS3Config();
      return;
    }

    const entry = deviceReach[deviceId];
    if (entry?.probing) return;

    const device = devices.find((d) => d.deviceId === deviceId);
    if (!device) return;

    const initialFreshLanUrl = freshLanUrlsRef.current[deviceId];
    const deviceForProbe = initialFreshLanUrl
      ? { ...device, lanHttpUrl: initialFreshLanUrl }
      : device;

    void checkS3Config();

    const nearbyIds = new Set(lanDevices.map((d) => d.deviceId));
    for (const d of otherDevices) {
      if (d.lanHttpUrl?.trim()) nearbyIds.add(d.deviceId);
    }
    const myDeviceIds = new Set(otherDevices.map((d) => d.deviceId));
    const priority = classifyDevice(deviceForProbe, nearbyIds, myDeviceIds);
    const orderedIds = diagnosticStepOrder(priority);

    setConnectionDiagnostic({
      peerId: deviceId,
      peerLabel: peerLabelForDevice(deviceForProbe),
      steps: orderedIds.map((id) => ({
        id,
        title: diagnosticStepTitle(t, id),
        status: 'pending',
      })),
      running: true,
    });
    setDiagnosticSheetOpen(true);

    applyDeviceReach(deviceId, {
      methods: entry?.methods ?? {
        directHttp: false,
        peerHttpHealthy: false,
        pullReachable: false,
        webrtc: false,
        lanSignaling: false,
      },
      probing: true,
    });

    const session = ++diagnosticSessionRef.current;

    void (async () => {
      let s3Available = s3Configured && s3Online;
      try {
        const { methods, freshLanUrl } = await runConnectionDiagnostic({
          device: deviceForProbe,
          initialFreshLanUrl,
          orderedStepIds: orderedIds,
          connected,
          isLoggedIn: !!userId,
          webrtcAvailable,
          onDirectHttpProbe: directHttpProbe,
          onLanHttpProbe: sendLanHttpProbe,
          onPullProbe: sendPullProbe,
          onWebRTCProbe: sendWebRTCProbe,
          onCheckS3: async () => {
            const result = await checkS3ForDiagnostic();
            s3Available = result.configured && result.online;
            return result;
          },
          t,
          onStepUpdate: (steps) => {
            if (diagnosticSessionRef.current !== session) return;
            setConnectionDiagnostic((prev) =>
              prev && prev.peerId === deviceId ? { ...prev, steps } : prev,
            );
          },
          isCancelled: () => diagnosticSessionRef.current !== session,
        });

        if (diagnosticSessionRef.current !== session) return;

        applyDeviceReach(
          deviceId,
          { methods, probing: false },
          freshLanUrl,
        );

        const summary = buildDiagnosticSummary(t, methods, {
          peerIsWeb: isPeerWebDevice(deviceForProbe),
          webrtcAvailable,
          s3Available,
        });

        setConnectionDiagnostic((prev) =>
          prev && prev.peerId === deviceId
            ? { ...prev, running: false, summary }
            : prev,
        );
      } catch (e) {
        logger.warn(TAG, 'runSessionConnectionDiagnostic failed', e);
        if (diagnosticSessionRef.current !== session) return;
        applyDeviceReach(deviceId, {
          methods: {
            directHttp: false,
            peerHttpHealthy: false,
            pullReachable: false,
            webrtc: false,
            lanSignaling: false,
          },
          probing: false,
        });
        setConnectionDiagnostic((prev) =>
          prev && prev.peerId === deviceId
            ? {
                ...prev,
                running: false,
                summary: t('chat.connectionDiag.summaryNoRoute'),
              }
            : prev,
        );
      }
    })();
  }, [
    deviceReach,
    devices,
    otherDevices,
    lanDevices,
    connected,
    userId,
    webrtcAvailable,
    directHttpProbe,
    sendLanHttpProbe,
    sendPullProbe,
    sendWebRTCProbe,
    checkS3ForDiagnostic,
    checkS3Config,
    applyDeviceReach,
    freshLanUrlsRef,
    t,
    s3Configured,
    s3Online,
  ]);

  useEffect(() => {
    if (!userId || !accessToken) return;
    void checkS3Config();
  }, [userId, accessToken, checkS3Config]);

  useEffect(() => {
    const onS3Settings = pathname?.startsWith('/settings/s3') ?? false;
    if (prevOnS3SettingsRef.current && !onS3Settings && userId) {
      void checkS3Config();
    }
    prevOnS3SettingsRef.current = onS3Settings;
  }, [pathname, checkS3Config, userId]);

  const refreshSendTargets = useCallback(() => {
    void checkS3Config();
    setProbeForceAll(true);
    setTargetProbeToken((t) => t + 1);
    loadDevices();
  }, [loadDevices, checkS3Config]);

  const refreshDevices = loadDevices;

  // Initial probe when connected and devices available
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

  // ─── Message loading ──────────────────────────────────────────────────

  const loadMoreMessages = useCallback(async () => {
    if (loadingMoreRef.current || hasNoMoreRef.current) return;
    if (!userId || !selectedDeviceId) return;
    const outbound = outboundForWebChat(userId, selectedDeviceId, getOrCreateDeviceId());
    if (!outbound) return;
    loadingMoreRef.current = true;
    setLoadingMore(true);
    try {
      const oldest = messages[0];
      if (!oldest) return;
      const before = (oldest as ChatMessage & { id?: number }).id;
      if (before == null) return;
      const list = await getMessageHistory(CHAT_PAGE_SIZE, before, outbound.threadKey);
      const filtered = list.filter((m) => !EPHEMERAL_TYPES.has(m.type));
      if (list.length < CHAT_PAGE_SIZE) hasNoMoreRef.current = true;
      if (filtered.length > 0) {
        setMessages((prev) => [...(filtered.reverse() as ChatMessage[]), ...prev]);
      }
    } catch (e) {
      logger.warn(TAG, 'loadMoreMessages failed', e);
    } finally {
      loadingMoreRef.current = false;
      setLoadingMore(false);
    }
  }, [messages, userId, selectedDeviceId]);

  // ─── Text sending ─────────────────────────────────────────────────────

  const sendTextMessage = useCallback(async (text: string) => {
    if (!text.trim() || sending) return;
    if (!userId || !selectedDeviceId) return;
    const outbound = outboundForWebChat(userId, selectedDeviceId, getOrCreateDeviceId());
    if (!outbound) return;
    setSending(true);
    const localId = generateUUID();
    const deviceId = getOrCreateDeviceId();
    const envelope: ChatMessage = {
      type: 'text',
      payload: { text, localId },
      fromDeviceId: deviceId,
      ts: Date.now(),
      toDeviceId: outbound.toDeviceId,
      threadKey: outbound.threadKey,
      _localId: localId,
      _status: 'sending',
    };
    setMessages((prev) => [...prev, envelope]);
    setSendError(null);
    const trimmed = text.trim();
    const lengthBucket = analyticsLengthBucket(trimmed.length);
    try {
      await sendMessage({
        type: envelope.type,
        payload: envelope.payload,
        fromDeviceId: envelope.fromDeviceId,
        ts: envelope.ts,
        threadKey: outbound.threadKey,
        ...(outbound.toDeviceId != null ? { toDeviceId: outbound.toDeviceId } : {}),
      });
      updateMessageByLocalId(localId, { _status: 'sent' });
      analyticsTrack(AnalyticsEvents.chatTextSend, {
        result: 'sent',
        offline: false,
        channel: 'api',
        length_bucket: lengthBucket,
      });
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'chat.sendFailed';
      logger.warn(TAG, 'sendMessage failed', msg);
      setSendError(msg);
      updateMessageByLocalId(localId, { _status: 'failed' });
      analyticsTrack(AnalyticsEvents.chatTextSend, {
        result: 'failed',
        offline: false,
        channel: 'api',
        length_bucket: lengthBucket,
      });
    } finally {
      setSending(false);
    }
  }, [sending, updateMessageByLocalId, userId, selectedDeviceId]);

  // ─── File sending ─────────────────────────────────────────────────────

  const sendSingleFile = useCallback(async (file: File, useLan: boolean, targetDevices: DeviceDto[]) => {
    const localId = generateUUID();
    const deviceId = getOrCreateDeviceId();
    if (!userId || !selectedDeviceId) {
      setFileError('chat.errors.needSessionDevice');
      return;
    }
    const outbound = outboundForWebChat(userId, selectedDeviceId, deviceId);
    if (!outbound) {
      setFileError('chat.errors.needSessionDevice');
      return;
    }
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
      const placeholder: ChatMessage = { type: 'file', payload: lanPayload, fromDeviceId: deviceId, ts: Date.now(), _localId: localId, _status: 'uploading', _progress: 0 };
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
        await sendMessage({
          type: 'file',
          payload: lanPayload,
          fromDeviceId: deviceId,
          ts: Date.now(),
          threadKey: outbound.threadKey,
          ...(outbound.toDeviceId != null ? { toDeviceId: outbound.toDeviceId } : {}),
        });
        retryInfoRef.current.delete(localId);
        updateMessageByLocalId(localId, { _status: 'sent', _progress: undefined, _speed: undefined });
      } catch (e) {
        if (e instanceof DOMException && e.name === 'AbortError') {
          updateMessageByLocalId(localId, { _status: 'cancelled', _progress: undefined, _speed: undefined });
          return;
        }
        const errMsg = e instanceof Error ? e.message : String(e);
        if (
          errMsg.includes(TRANSFER_STALL_TIMEOUT_MESSAGE) ||
          errMsg.includes('停滞') ||
          errMsg.includes('stall') ||
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

    if (!s3Configured) {
      setFileError('chat.errors.configureS3First');
      activeTransfersRef.current.delete(localId);
      return;
    }
    if (!s3Online) {
      setFileError('chat.errors.s3Unavailable');
      activeTransfersRef.current.delete(localId);
      return;
    }
    retryInfoRef.current.set(localId, { file, channel: 's3', targetDevices: [] });
    const placeholder: ChatMessage = { type: 'file', payload: { fileName: file.name, size: file.size, localId }, fromDeviceId: deviceId, ts: Date.now(), _localId: localId, _status: 'uploading', _progress: 0 };
    setMessages((prev) => [...prev, placeholder]);
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
          }
        },
        abortController.signal,
      );
      const s3Tk = threadKeyForS3WebPersist(userId, deviceId, outbound.toDeviceId);
      await sendMessage({
        type: 'file',
        payload: { key: result.key, fileName: file.name, size: file.size, localId },
        fromDeviceId: deviceId,
        ts: Date.now(),
        threadKey: s3Tk,
        ...(outbound.toDeviceId != null ? { toDeviceId: outbound.toDeviceId } : {}),
      });
      retryInfoRef.current.delete(localId);
      updateMessageByLocalId(localId, { _status: 'sent', _progress: undefined, _speed: undefined, payload: { key: result.key, fileName: file.name, size: file.size, localId } });
    } catch (e) {
      if (e instanceof DOMException && e.name === 'AbortError') {
        updateMessageByLocalId(localId, { _status: 'cancelled', _progress: undefined, _speed: undefined });
        return;
      }
      setFileError(e instanceof Error ? e.message : 'chat.sendFailed');
      updateMessageByLocalId(localId, { _status: 'failed', _speed: undefined });
    } finally {
      activeTransfersRef.current.delete(localId);
      speedTrackersRef.current.delete(localId);
    }
  }, [updateMessageByLocalId, userId, selectedDeviceId, s3Configured, s3Online]);

  const sendFilesViaWebRTC = useCallback(async (files: File[], targetDeviceId: string) => {
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
      speedTrackersRef.current.set(localId, new SpeedTracker());
      const placeholder: ChatMessage = { type: 'file', payload: { fileName: meta.fileName, size: meta.fileSize, webrtc: true, localId }, fromDeviceId: deviceId, ts: Date.now(), _localId: localId, _status: 'uploading', _progress: 0 };
      setMessages((prev) => [...prev, placeholder]);
    }
    try {
      const session = await mgr.initiateTransfer(targetDeviceId, pendingWithMeta);
      await session.connected;
      await session.sendsFinished;
    } catch (err) {
      if (s3OnlineRef.current) {
        await runWithConcurrency(pendingWithMeta, MAX_PARALLEL_FILE_SENDS, async ({ file, meta }) => {
          const localId = webrtcFileLocalIdMap.current.get(meta.fileId);
          if (localId) {
            webrtcFileLocalIdMap.current.delete(meta.fileId);
            webrtcFileSizeMap.current.delete(meta.fileId);
            speedTrackersRef.current.delete(localId);
            updateMessageByLocalId(localId, { _status: 'uploading', _progress: 0, _speed: undefined, payload: { fileName: file.name, size: file.size } });
          }
          await sendSingleFile(file, false, []);
        });
      } else {
        const peer = devices.find((d) => d.deviceId === targetDeviceId);
        setFileError(
          isWebPeer(peer?.platform)
            ? 'chat.errors.webrtcTryS3'
            : 'chat.errors.webrtcTryHttp',
        );
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
  }, [updateMessageByLocalId, sendSingleFile, devices]);

  useEffect(() => {
    sendSingleFileRef.current = sendSingleFile;
    sendFilesViaWebRTCRef.current = sendFilesViaWebRTC;
  });

  // ─── LAN verification ─────────────────────────────────────────────────

  const tryResolveLanUrl = useCallback(async (device: DeviceDto): Promise<string | null> => {
    const baseUrl = device.lanHttpUrl;
    if (!baseUrl) return null;
    let parsed: URL;
    try { parsed = new URL(baseUrl); } catch { return null; }
    if (await probeHttpWeb(baseUrl, 1500)) return baseUrl;
    if (await probeHttpWeb(baseUrl, 3000)) return baseUrl;
    const currentPort = parsed.port ? Number(parsed.port) : (parsed.protocol === 'https:' ? 443 : 80);
    const scanPorts: number[] = [];
    for (let p = 9080; p <= 9100; p++) { if (p !== currentPort) scanPorts.push(p); }
    const candidates = scanPorts.map((p) => `${parsed.protocol}//${parsed.hostname}:${p}`);
    const found = await Promise.all(candidates.map(async (url) => ({ url, ok: await probeHttpWeb(url, 900) })));
    const hit = found.find((x) => x.ok);
    return hit?.url ?? null;
  }, []);

  const verifyLanTargets = useCallback(async (targets: DeviceDto[]): Promise<DeviceDto[]> => {
    if (targets.length === 0) return [];
    const results = await Promise.all(targets.map(async (d) => {
      const resolvedUrl = await tryResolveLanUrl(d);
      if (!resolvedUrl) return null;
      if (resolvedUrl !== d.lanHttpUrl) {
        try { await updateDevice(d.deviceId, { lanHttpUrl: resolvedUrl }); } catch (e) { logger.warn(TAG, 'updateDevice lanHttpUrl failed:', d.deviceId, e); }
      }
      return { ...d, lanHttpUrl: resolvedUrl } as DeviceDto;
    }));
    return results.filter((d): d is DeviceDto => d !== null);
  }, [tryResolveLanUrl]);

  // ─── File send orchestration ──────────────────────────────────────────

  const sendFileToTargets = useCallback(async (mode: 'webrtc' | 'lan' | 's3', selectedIds?: Set<string>, freshDevices?: DeviceDto[]) => {
    const filesToSend = [...pendingFiles];
    setPendingFiles([]);
    setFileError(null);
    if (filesToSend.length === 0) return;
    if (mode === 'webrtc' && selectedIds) {
      const targetIds = Array.from(selectedIds);
      await runWithConcurrency(targetIds, MAX_PARALLEL_WEBRTC_TARGETS, async (targetId) => {
        await sendFilesViaWebRTC(filesToSend, targetId);
      });
      return;
    }
    const useLan = mode === 'lan';
    const selectedLanTargets = useLan
      ? (freshDevices && freshDevices.length > 0 ? freshDevices : (selectedIds ? devices.filter((d) => selectedIds.has(d.deviceId) && d.lanHttpUrl) : []))
      : [];
    const targetDevices = useLan ? await verifyLanTargets(selectedLanTargets) : [];
    if (useLan && targetDevices.length === 0) {
      setFileError('chat.errors.preflightPartial');
      await runWithConcurrency(filesToSend, MAX_PARALLEL_FILE_SENDS, async (file) => { await sendSingleFile(file, true, selectedLanTargets); });
      return;
    }
    if (useLan && targetDevices.length < selectedLanTargets.length) {
      setFileError('chat.errors.skippedUnreachable');
    }
    await runWithConcurrency(filesToSend, MAX_PARALLEL_FILE_SENDS, async (file) => { await sendSingleFile(file, useLan, targetDevices); });
  }, [pendingFiles, devices, sendFilesViaWebRTC, sendSingleFile, verifyLanTargets]);

  const handleSendFiles = useCallback(() => {
    if (pendingFiles.length === 0) return;

    // S3 virtual device: always use S3
    if (selectedDeviceId === S3_VIRTUAL_DEVICE_ID || sendMode === 's3') {
      void sendFileToTargets('s3');
      return;
    }

    if (sendMode === 'webrtc' && !webrtcAvailable) {
      setFileError('chat.errors.webrtcNotSupported');
      return;
    }
    const selectedPeer = selectedDeviceId
      ? devices.find((d) => d.deviceId === selectedDeviceId)
      : undefined;
    if (sendMode === 'lan' && isWebPeer(selectedPeer?.platform)) {
      setFileError('chat.errors.httpNotSupportedWebPeer');
      return;
    }
    const onlineTargets = [...selectedTargets].filter(
      (id) => otherDevices.some((d) => d.deviceId === id) && isReachOnline(deviceReach[id]),
    );

    if (onlineTargets.length === 0) {
      setFileError('chat.errors.selectOnlineTargets');
      return;
    }

    if (sendMode === 'webrtc') {
      void sendFileToTargets('webrtc', new Set(onlineTargets));
      return;
    }
    if (sendMode === 'lan') {
      const lanOnline = new Set(onlineTargets.filter((id) => lanDevices.some((d) => d.deviceId === id)));
      void sendFileToTargets('lan', lanOnline, buildFreshLanDevices(lanOnline));
      return;
    }
  }, [pendingFiles, sendMode, selectedDeviceId, devices, webrtcAvailable, selectedTargets, otherDevices, lanDevices, deviceReach, sendFileToTargets, buildFreshLanDevices]);

  const handleFileSelect = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const fileList = e.target.files;
    if (!fileList || fileList.length === 0) return;
    const files = Array.from(fileList);
    e.target.value = '';
    setFileError(null);
    setPendingFiles((prev) => [...prev, ...files]);
  }, []);

  const removePendingFile = useCallback((index: number) => {
    setPendingFiles((prev) => prev.filter((_, i) => i !== index));
  }, []);

  // ─── Retry handlers ───────────────────────────────────────────────────

  const handleRetryText = useCallback(
    (localId: string) => {
      const msg = messages.find((m) => m._localId === localId && m.type === 'text');
      if (!msg || msg._status !== 'failed') return;
      const text = (msg.payload as { text?: string })?.text;
      if (!text) return;
      if (!userId || !selectedDeviceId) return;
      const outbound = outboundForWebChat(userId, selectedDeviceId, getOrCreateDeviceId());
      if (!outbound) return;
      updateMessageByLocalId(localId, { _status: 'sending' });
      const lengthBucket = analyticsLengthBucket(text.length);
      sendMessage({
        type: 'text',
        payload: msg.payload,
        fromDeviceId: msg.fromDeviceId,
        ts: Date.now(),
        threadKey: outbound.threadKey,
        ...(outbound.toDeviceId != null ? { toDeviceId: outbound.toDeviceId } : {}),
      })
        .then(() => {
          updateMessageByLocalId(localId, { _status: 'sent' });
          analyticsTrack(AnalyticsEvents.chatTextRetry, {
            result: 'sent',
            offline: false,
            channel: 'api',
            length_bucket: lengthBucket,
          });
        })
        .catch(() => {
          updateMessageByLocalId(localId, { _status: 'failed' });
          analyticsTrack(AnalyticsEvents.chatTextRetry, {
            result: 'failed',
            offline: false,
            channel: 'api',
            length_bucket: lengthBucket,
          });
        });
    },
    [messages, updateMessageByLocalId, userId, selectedDeviceId],
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
          const peerId = info.webrtcTargetDeviceId ?? selectedDeviceId;
          const peer = peerId ? devices.find((d) => d.deviceId === peerId) : undefined;
          setFileError(
            isWebPeer(peer?.platform)
              ? 'chat.errors.webrtcRetryS3'
              : 'chat.errors.webrtcRetryHttp',
          );
        }
        break;
      default:
        void sendSingleFileRef.current(info.file, false, []);
    }
  }, [devices, selectedDeviceId]);

  // ─── Message management ───────────────────────────────────────────────

  const handleDeleteMessage = useCallback(async (msg: ChatMessage) => {
    const msgId = msg.id;
    if (msgId != null) {
      try { await deleteMessage(msgId); } catch { logger.warn(TAG, 'deleteMessage failed', msgId); }
    }
    setMessages((prev) => prev.filter((m) => msg._localId ? m._localId !== msg._localId : m !== msg));
  }, []);

  // ─── Multi-select ─────────────────────────────────────────────────────

  const getMessageSelectKey = useCallback((msg: ChatMessage): string | null => {
    if (msg.id != null) return `id:${msg.id}`;
    if (msg._localId) return `local:${msg._localId}`;
    return null;
  }, []);

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
  }, [messages, getMessageSelectKey]);

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
        try { await deleteMessage(msg.id); } catch { logger.warn(TAG, 'bulk deleteMessage failed', msg.id); }
      }
    }
    setMessages((prev) => prev.filter((m) => { const k = getMessageSelectKey(m); return !k || !keys.has(k); }));
    exitSelectMode();
  }, [messages, selectedKeys, exitSelectMode, getMessageSelectKey, t]);

  const clearCurrentThreadMessages = useCallback(async () => {
    const uid = userIdRef.current;
    const peer = selectedDeviceIdRef.current;
    if (!uid || !peer) return;
    const outbound = outboundForWebChat(uid, peer, getOrCreateDeviceId());
    if (!outbound) return;
    await deleteThreadMessages(outbound.threadKey);
    setMessages([]);
    hasNoMoreRef.current = true;
  }, []);

  useEffect(() => {
    if (!selectMode) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') exitSelectMode(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [selectMode, exitSelectMode]);

  // ─── Auto-select best send mode for a device ─────────────────────────

  const bestSendModeForDevice = useCallback((deviceId: string): WebSendMode => {
    if (deviceId === S3_VIRTUAL_DEVICE_ID) return 's3';
    const peer = devices.find((d) => d.deviceId === deviceId);
    if (isWebPeer(peer?.platform)) {
      const entry = deviceReach[deviceId];
      if (isReachOnline(entry) && webrtcAvailable && entry.methods.webrtc) {
        return 'webrtc';
      }
      if (s3Configured && s3Online) return 's3';
      return 'webrtc';
    }
    const entry = deviceReach[deviceId];
    if (isReachOnline(entry)) {
      if ((entry.methods.directHttp || entry.methods.lanSignaling) && lanDevices.some((d) => d.deviceId === deviceId)) return 'lan';
      if (webrtcAvailable && entry.methods.webrtc) return 'webrtc';
      if (s3Configured && s3Online) return 's3';
    }
    if (s3Configured && s3Online) return 's3';
    return 'lan';
  }, [deviceReach, lanDevices, webrtcAvailable, devices, s3Configured, s3Online]);

  // ─── Auto-select device as target when selectedDeviceId changes ──────

  const probeSingleRef = useRef(probeSingleDevice);
  probeSingleRef.current = probeSingleDevice;
  const reconcileSendModeRef = useRef(reconcileSendModeForSelection);
  reconcileSendModeRef.current = reconcileSendModeForSelection;

  useEffect(() => {
    if (!selectedDeviceId) return;
    if (selectedDeviceId === S3_VIRTUAL_DEVICE_ID) {
      setSendMode('s3');
      return;
    }
    sendModeAutoRef.current = true;
    const peer = devices.find((d) => d.deviceId === selectedDeviceId);
    selectedPeerReachSnapshotRef.current = peer
      ? {
          presence: peer.presenceStatus ?? '',
          lanHttpUrl: peer.lanHttpUrl ?? '',
        }
      : null;
    setSelectedTargets((prev) => {
      if (prev.has(selectedDeviceId)) return prev;
      const next = new Set([selectedDeviceId]);
      persistSelectedTargets(next);
      return next;
    });
    probeSingleRef.current(selectedDeviceId);
  }, [selectedDeviceId, devices]);

  useEffect(() => {
    if (!selectedDeviceId || selectedDeviceId === S3_VIRTUAL_DEVICE_ID) return;
    const peer = devices.find((d) => d.deviceId === selectedDeviceId);
    if (!peer) return;

    const presence = peer.presenceStatus ?? '';
    const lanHttpUrl = peer.lanHttpUrl ?? '';
    const snap = selectedPeerReachSnapshotRef.current;
    if (!snap) return;

    let shouldProbe = false;
    if (snap.presence === 'offline' && presence !== 'offline') {
      shouldProbe = true;
    }
    if (lanHttpUrl.length > 0 && lanHttpUrl !== snap.lanHttpUrl) {
      shouldProbe = true;
    }

    selectedPeerReachSnapshotRef.current = { presence, lanHttpUrl };
    if (shouldProbe) {
      probeSingleRef.current(selectedDeviceId);
    }
  }, [selectedDeviceId, devices]);

  useEffect(() => {
    if (!selectedDeviceId || selectedDeviceId === S3_VIRTUAL_DEVICE_ID) return;
    const resolved = reconcileSendModeRef.current(selectedDeviceId);
    setSendMode(resolved);
  }, [selectedDeviceId, deviceReach, reconcileSendModeForSelection, webrtcAvailable, s3Configured, s3Online]);

  useEffect(() => {
    if (!selectedDeviceId) return;
    analyticsTrack(AnalyticsEvents.chatSessionOpen, {
      session_type: selectedDeviceId === S3_VIRTUAL_DEVICE_ID ? 's3' : 'peer',
    });
  }, [selectedDeviceId]);

  // ─── Context value ────────────────────────────────────────────────────

  const value = useMemo<ChatContextValue>(() => ({
    connected,
    devices,
    currentDeviceId,
    otherDevices,
    lanDevices,
    refreshDevices,
    selectedDeviceId,
    setSelectedDeviceId,
    sendMode,
    onSendModeChange,
    selectedTargets,
    toggleTarget,
    deviceReach,
    targetsProbing,
    refreshSendTargets,
    probeSingleDevice,
    runSessionConnectionDiagnostic,
    connectionDiagnostic,
    diagnosticSheetOpen,
    setDiagnosticSheetOpen,
    messages,
    sendTextMessage,
    sending,
    sendError,
    setSendError,
    fileError,
    setFileError,
    pendingFiles,
    setPendingFiles,
    handleSendFiles,
    handleFileSelect,
    removePendingFile,
    handleDeleteMessage,
    cancelTransfer,
    handleRetryText,
    handleRetryFile,
    loadMoreMessages,
    loadingMore,
    selectMode,
    selectedKeys,
    toggleMessageSelect,
    exitSelectMode,
    toggleSelectAllMessages,
    enterSelectWithKey,
    handleBulkDelete,
    clearCurrentThreadMessages,
    webrtcAvailable,
    s3Configured,
    s3Online,
    s3Checking,
    checkS3Config,
    bestSendModeForDevice,
  }), [
    connected, devices, currentDeviceId, otherDevices, lanDevices, refreshDevices,
    selectedDeviceId, sendMode, onSendModeChange, selectedTargets, toggleTarget,
    deviceReach, targetsProbing, refreshSendTargets, probeSingleDevice,
    runSessionConnectionDiagnostic, connectionDiagnostic, diagnosticSheetOpen, setDiagnosticSheetOpen,
    messages, sendTextMessage, sending, sendError, fileError,
    pendingFiles, handleSendFiles, handleFileSelect, removePendingFile,
    handleDeleteMessage, cancelTransfer, handleRetryText, handleRetryFile,
    loadMoreMessages, loadingMore,
    selectMode, selectedKeys, toggleMessageSelect, exitSelectMode, toggleSelectAllMessages, enterSelectWithKey, handleBulkDelete, clearCurrentThreadMessages,
    webrtcAvailable, s3Configured, s3Online, s3Checking, checkS3Config, bestSendModeForDevice, probeSingleDevice,
    runSessionConnectionDiagnostic, connectionDiagnostic, diagnosticSheetOpen, setDiagnosticSheetOpen,
  ]);

  return <ChatContext.Provider value={value}>{children}</ChatContext.Provider>;
}
