'use client';

import { useCallback, useEffect, useState } from 'react';
import {
  AUTO_COPY_CHANGED_EVENT,
  AUTO_COPY_STORAGE_KEY,
  loadAutoCopyIncomingText,
  persistAutoCopyIncomingText,
} from '@/lib/autoCopyPreferences';

export function useAutoCopyIncomingText(): [boolean, (enabled: boolean) => void] {
  const [enabled, setEnabledState] = useState<boolean>(() => loadAutoCopyIncomingText());

  useEffect(() => {
    const onChanged = (event: Event) => {
      const detail = (event as CustomEvent<{ value?: boolean }>).detail;
      if (typeof detail?.value === 'boolean') {
        setEnabledState(detail.value);
        return;
      }
      setEnabledState(loadAutoCopyIncomingText());
    };

    const onStorage = (event: StorageEvent) => {
      if (event.key === AUTO_COPY_STORAGE_KEY) {
        setEnabledState(loadAutoCopyIncomingText());
      }
    };

    window.addEventListener(AUTO_COPY_CHANGED_EVENT, onChanged);
    window.addEventListener('storage', onStorage);
    return () => {
      window.removeEventListener(AUTO_COPY_CHANGED_EVENT, onChanged);
      window.removeEventListener('storage', onStorage);
    };
  }, []);

  const setEnabled = useCallback((next: boolean) => {
    persistAutoCopyIncomingText(next);
    setEnabledState(next);
  }, []);

  return [enabled, setEnabled];
}
