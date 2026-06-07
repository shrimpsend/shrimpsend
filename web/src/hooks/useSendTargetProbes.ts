'use client';

import { useCallback, useEffect, useMemo, useRef, useState, type MutableRefObject } from 'react';
import type { DeviceDto } from '@/lib/api';
import { logger } from '@/lib/logger';
import {
  partitionForProbe,
  runWithConcurrency,
  shouldSkipAutoProbe,
} from '@/lib/probePriority';

const TAG = 'useSendTargetProbes';

/** UI display status (checking is probe progress, not device state). */
export type ReachStatus = 'checking' | 'online' | 'offline';

export type DeviceReachDetail = {
  directHttp: boolean;
  /** Peer HTTP self-check via signaling. */
  peerHttpHealthy: boolean;
  /** Reverse pull direction (peer can reach this device). */
  pullReachable: boolean;
  webrtc: boolean;
  /** @deprecated use peerHttpHealthy */
  lanSignaling: boolean;
};

export type DeviceReachEntry = {
  methods: DeviceReachDetail;
  probing: boolean;
};

const offlineMethods: DeviceReachDetail = {
  directHttp: false,
  peerHttpHealthy: false,
  pullReachable: false,
  webrtc: false,
  lanSignaling: false,
};
const offlineEntry: DeviceReachEntry = { methods: offlineMethods, probing: false };

export function isReachOnline(entry?: DeviceReachEntry): boolean {
  const m = entry?.methods;
  return !!(
    m?.directHttp ||
    m?.pullReachable ||
    m?.peerHttpHealthy ||
    m?.lanSignaling ||
    m?.webrtc
  );
}

export function isPullOnlyReach(entry?: DeviceReachEntry): boolean {
  const m = entry?.methods;
  return !!(m?.pullReachable && !m?.directHttp);
}

export function getReachDisplayStatus(entry?: DeviceReachEntry): ReachStatus {
  if (isReachOnline(entry)) return 'online';
  if (entry?.probing) return 'checking';
  return 'offline';
}

export function reachSortPriority(entry?: DeviceReachEntry): number {
  return isReachOnline(entry) ? 0 : 1;
}

function initialReachEntry(): DeviceReachEntry {
  return offlineEntry;
}

function toProbingEntry(prev?: DeviceReachEntry): DeviceReachEntry {
  return {
    methods: prev?.methods ?? offlineMethods,
    probing: true,
  };
}

function toResolvedEntry(methods: DeviceReachDetail): DeviceReachEntry {
  return { methods, probing: false };
}

function buildFromDevicePresence(devices: DeviceDto[]): Record<string, DeviceReachEntry> {
  const m: Record<string, DeviceReachEntry> = {};
  for (const device of devices) m[device.deviceId] = initialReachEntry();
  return m;
}

function mergeReachOnListChange(
  prev: Record<string, DeviceReachEntry>,
  devices: DeviceDto[],
  connected: boolean,
): Record<string, DeviceReachEntry> {
  if (!connected) return buildFromDevicePresence(devices);
  const next: Record<string, DeviceReachEntry> = {};
  for (const device of devices) {
    next[device.deviceId] = device.presenceStatus === 'offline'
      ? offlineEntry
      : (prev[device.deviceId] ?? offlineEntry);
  }
  return next;
}

/** Probe all methods; skips signaling/WebRTC when direct HTTP succeeds. */
async function probeDeviceAllMethods(
  device: DeviceDto,
  nearbyIds: Set<string>,
  onDirectHttpProbe: (url: string) => Promise<boolean>,
  onLanHttpProbe: (deviceId: string) => Promise<{ success: boolean; lanHttpUrl?: string; senderReachable?: boolean }>,
  onWebRTCProbe: (deviceId: string) => Promise<boolean>,
  { forceFull = false }: { forceFull?: boolean } = {},
): Promise<{ methods: DeviceReachDetail; freshLanUrl?: string }> {
  if (!forceFull && shouldSkipAutoProbe(device, nearbyIds)) {
    return { methods: offlineMethods };
  }

  const lanUrl = device.lanHttpUrl?.trim();
  if (lanUrl) {
    try {
      const ok = await onDirectHttpProbe(lanUrl);
      if (ok) {
        return {
          methods: {
            directHttp: true,
            peerHttpHealthy: false,
            pullReachable: false,
            webrtc: false,
            lanSignaling: false,
          },
          freshLanUrl: lanUrl,
        };
      }
    } catch {
      // fall through to signaling
    }
  }

  const results = await Promise.allSettled([
    Promise.resolve({ ok: false, url: undefined as string | undefined }),
    (async () => {
      const result = await onLanHttpProbe(device.deviceId);
      return {
        peerOk: result.success,
        pullOk: result.senderReachable === true,
        url: result.lanHttpUrl,
      };
    })(),
    onWebRTCProbe(device.deviceId),
  ]);

  const lanResult = results[1].status === 'fulfilled'
    ? results[1].value
    : { peerOk: false, pullOk: false, url: undefined as string | undefined };
  const webrtcOk = results[2].status === 'fulfilled' ? results[2].value : false;

  const freshLanUrl = lanResult.url;
  const peerHttpHealthy = lanResult.peerOk;
  const pullReachable = lanResult.pullOk;

  return {
    methods: {
      directHttp: false,
      peerHttpHealthy,
      pullReachable,
      webrtc: webrtcOk,
      lanSignaling: peerHttpHealthy,
    },
    freshLanUrl,
  };
}

export function useSendTargetProbes(
  otherDevices: DeviceDto[],
  lanDevices: DeviceDto[],
  connected: boolean,
  probeToken: number,
  probeForceAll: boolean,
  onWebRTCProbe: (targetDeviceId: string) => Promise<boolean>,
  onLanHttpProbe: (
    targetDeviceId: string,
  ) => Promise<{ success: boolean; lanHttpUrl?: string; senderReachable?: boolean }>,
  onDirectHttpProbe: (url: string) => Promise<boolean>,
): {
  deviceReach: Record<string, DeviceReachEntry>;
  freshLanUrlsRef: MutableRefObject<Record<string, string>>;
  probing: boolean;
  probeSingleDevice: (deviceId: string) => void;
} {
  const deviceFingerprint = useMemo(
    () =>
      otherDevices
        .map(
          (d) =>
            `${d.deviceId}:${d.presenceStatus ?? ''}:${d.presenceUpdatedAt ?? ''}:${d.lanHttpUrl ?? ''}`,
        )
        .join(','),
    [otherDevices],
  );

  const myDeviceIds = useMemo(
    () => new Set(otherDevices.map((d) => d.deviceId)),
    [otherDevices],
  );
  const nearbyIds = useMemo(() => {
    const ids = new Set(lanDevices.map((d) => d.deviceId));
    for (const d of otherDevices) {
      if (d.lanHttpUrl?.trim()) ids.add(d.deviceId);
    }
    return ids;
  }, [otherDevices, lanDevices]);

  const [deviceReach, setDeviceReach] = useState<Record<string, DeviceReachEntry>>(() =>
    buildFromDevicePresence(otherDevices),
  );
  const [probing, setProbing] = useState(false);

  const freshLanUrlsRef = useRef<Record<string, string>>({});
  const deviceSnapshotRef = useRef(otherDevices);
  deviceSnapshotRef.current = otherDevices;
  const nearbyIdsRef = useRef(nearbyIds);
  nearbyIdsRef.current = nearbyIds;
  const myDeviceIdsRef = useRef(myDeviceIds);
  myDeviceIdsRef.current = myDeviceIds;

  useEffect(() => {
    const ids = otherDevices.map((d) => d.deviceId);
    setDeviceReach((prev) => mergeReachOnListChange(prev, otherDevices, connected));

    const allowed = new Set(ids);
    const urls = { ...freshLanUrlsRef.current };
    for (const k of Object.keys(urls)) {
      if (!allowed.has(k)) delete urls[k];
    }
    freshLanUrlsRef.current = urls;
  }, [deviceFingerprint, connected, otherDevices]);

  useEffect(() => {
    const cancelledRef = { current: false };
    if (probeToken === 0 || !connected) {
      return () => { cancelledRef.current = true; };
    }

    const snap = deviceSnapshotRef.current;
    const partition = partitionForProbe(
      snap,
      nearbyIdsRef.current,
      myDeviceIdsRef.current,
    );
    const toProbe = probeForceAll
      ? snap
      : [...partition.lanDiscovered, ...partition.presenceOnline];

    logger.info(
      TAG,
      'probe run token=',
      probeToken,
      'forceAll=',
      probeForceAll,
      'auto=',
      toProbe.length,
      'lazy=',
      partition.lazy.length,
    );

    setDeviceReach((prev) => {
      const next = { ...prev };
      for (const d of toProbe) next[d.deviceId] = toProbingEntry(prev[d.deviceId]);
      if (!probeForceAll) {
        for (const d of partition.lazy) next[d.deviceId] = offlineEntry;
      }
      return next;
    });

    if (toProbe.length === 0) {
      setProbing(false);
      return () => { cancelledRef.current = true; };
    }

    setProbing(true);

    const applyResult = (
      deviceId: string,
      methods: DeviceReachDetail,
      freshLanUrl?: string,
    ) => {
      if (cancelledRef.current) return;
      if (freshLanUrl) {
        freshLanUrlsRef.current = { ...freshLanUrlsRef.current, [deviceId]: freshLanUrl };
      }
      setDeviceReach((prev) => ({
        ...prev,
        [deviceId]: toResolvedEntry(methods),
      }));
    };

    const probeOne = async (d: DeviceDto, forceFull: boolean) => {
      try {
        const { methods, freshLanUrl } = await probeDeviceAllMethods(
          d,
          nearbyIdsRef.current,
          onDirectHttpProbe,
          onLanHttpProbe,
          onWebRTCProbe,
          { forceFull },
        );
        applyResult(d.deviceId, methods, freshLanUrl);
      } catch {
        applyResult(d.deviceId, offlineMethods);
      }
    };

    void (async () => {
      try {
        if (probeForceAll) {
          await runWithConcurrency(toProbe, 3, (d) => probeOne(d, true));
        } else {
          await runWithConcurrency(partition.lanDiscovered, 6, (d) => probeOne(d, false));
          if (cancelledRef.current) return;
          await runWithConcurrency(partition.presenceOnline, 3, (d) => probeOne(d, false));
        }
      } finally {
        if (!cancelledRef.current) setProbing(false);
      }
    })();

    return () => { cancelledRef.current = true; };
  }, [probeToken, probeForceAll, connected, onWebRTCProbe, onLanHttpProbe, onDirectHttpProbe]);

  const probeSingleDevice = useCallback((deviceId: string) => {
    if (!connected) return;
    const device = deviceSnapshotRef.current.find((d) => d.deviceId === deviceId);
    if (!device) return;

    setDeviceReach((prev) => ({
      ...prev,
      [deviceId]: toProbingEntry(prev[deviceId]),
    }));
    void (async () => {
      const { methods, freshLanUrl } = await probeDeviceAllMethods(
        device,
        nearbyIdsRef.current,
        onDirectHttpProbe,
        onLanHttpProbe,
        onWebRTCProbe,
        { forceFull: true },
      );
      if (freshLanUrl) {
        freshLanUrlsRef.current = { ...freshLanUrlsRef.current, [deviceId]: freshLanUrl };
      }
      setDeviceReach((prev) => ({
        ...prev,
        [deviceId]: toResolvedEntry(methods),
      }));
    })();
  }, [connected, onDirectHttpProbe, onLanHttpProbe, onWebRTCProbe]);

  return { deviceReach, freshLanUrlsRef, probing, probeSingleDevice };
}

export function sortDevicesByReach(
  devices: DeviceDto[],
  statusMap: Record<string, DeviceReachEntry>,
): DeviceDto[] {
  return [...devices].sort(
    (a, b) => reachSortPriority(statusMap[a.deviceId]) - reachSortPriority(statusMap[b.deviceId]),
  );
}
