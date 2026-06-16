/** Auto-copy preferences. Align keys with Flutter `clipboard_preferences.dart`. */

const KEY_AUTO_COPY_INCOMING_TEXT = 'ultrasend_auto_copy_received_text';

export const AUTO_COPY_CHANGED_EVENT = 'ultrasend:auto-copy-changed';

/** Whether incoming text from other devices is auto-copied. Enabled by default. */
export function loadAutoCopyIncomingText(): boolean {
  try {
    const v = localStorage.getItem(KEY_AUTO_COPY_INCOMING_TEXT);
    if (v === null) return true;
    return v === 'true';
  } catch {
    return true;
  }
}

export function persistAutoCopyIncomingText(enabled: boolean): void {
  try {
    localStorage.setItem(KEY_AUTO_COPY_INCOMING_TEXT, enabled ? 'true' : 'false');
    window.dispatchEvent(
      new CustomEvent(AUTO_COPY_CHANGED_EVENT, {
        detail: { value: enabled },
      }),
    );
  } catch {
    /* ignore */
  }
}

export const AUTO_COPY_STORAGE_KEY = KEY_AUTO_COPY_INCOMING_TEXT;
