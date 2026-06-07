import type { DeviceDto } from '@/lib/api';

export type ProbePriority = 'lanDiscovered' | 'presenceOnline' | 'lazy';

export type ProbePartition = {
  lanDiscovered: DeviceDto[];
  presenceOnline: DeviceDto[];
  lazy: DeviceDto[];
};

export function classifyDevice(
  device: DeviceDto,
  nearbyIds: Set<string>,
  myDeviceIds: Set<string>,
): ProbePriority {
  const hasLanUrl = !!(device.lanHttpUrl && device.lanHttpUrl.trim().length > 0);
  if (hasLanUrl || nearbyIds.has(device.deviceId)) return 'lanDiscovered';
  if (myDeviceIds.has(device.deviceId) && device.presenceStatus === 'online') {
    return 'presenceOnline';
  }
  return 'lazy';
}

export function partitionForProbe(
  devices: DeviceDto[],
  nearbyIds: Set<string>,
  myDeviceIds: Set<string>,
): ProbePartition {
  const lanDiscovered: DeviceDto[] = [];
  const presenceOnline: DeviceDto[] = [];
  const lazy: DeviceDto[] = [];
  for (const d of devices) {
    switch (classifyDevice(d, nearbyIds, myDeviceIds)) {
      case 'lanDiscovered':
        lanDiscovered.push(d);
        break;
      case 'presenceOnline':
        presenceOnline.push(d);
        break;
      case 'lazy':
        lazy.push(d);
        break;
    }
  }
  return { lanDiscovered, presenceOnline, lazy };
}

export function shouldSkipAutoProbe(device: DeviceDto, nearbyIds: Set<string>): boolean {
  const hasLanUrl = !!(device.lanHttpUrl && device.lanHttpUrl.trim().length > 0);
  if (hasLanUrl || nearbyIds.has(device.deviceId)) return false;
  return device.presenceStatus === 'offline';
}

export async function runWithConcurrency<T>(
  items: T[],
  concurrency: number,
  fn: (item: T) => Promise<void>,
): Promise<void> {
  if (items.length === 0) return;
  const limit = Math.max(1, Math.min(concurrency, items.length));
  let nextIndex = 0;
  async function worker() {
    while (nextIndex < items.length) {
      const index = nextIndex++;
      await fn(items[index]);
    }
  }
  await Promise.all(Array.from({ length: limit }, () => worker()));
}
