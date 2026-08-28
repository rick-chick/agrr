export const PUBLIC_PLAN_STATE_STORAGE_KEY = 'agrr_public_plan_state';
export const PUBLIC_PLAN_SESSION_TOKEN_STORAGE_KEY = 'agrr_public_plan_session_token';
export const PENDING_PUBLIC_PLAN_SAVE_STORAGE_KEY = 'agrr_pending_public_plan_save';

export type BrowserStorageWriteResult =
  | { ok: true }
  | { ok: false; reason: 'unavailable' | 'quota_exceeded' | 'unknown' };

export function readBrowserStorageItem(key: string): string | null {
  if (typeof localStorage === 'undefined') {
    return readLegacySessionStorageItem(key);
  }
  try {
    const fromLocal = localStorage.getItem(key);
    if (fromLocal != null) {
      return fromLocal;
    }
    const migrated = migrateFromSessionStorage(key);
    return migrated;
  } catch {
    return readLegacySessionStorageItem(key);
  }
}

export function writeBrowserStorageItem(key: string, value: string): BrowserStorageWriteResult {
  if (typeof localStorage === 'undefined') {
    return { ok: false, reason: 'unavailable' };
  }
  try {
    localStorage.setItem(key, value);
    return { ok: true };
  } catch (error) {
    if (
      error instanceof DOMException &&
      (error.name === 'QuotaExceededError' || error.code === 22)
    ) {
      return { ok: false, reason: 'quota_exceeded' };
    }
    return { ok: false, reason: 'unknown' };
  }
}

export function removeBrowserStorageItem(key: string): void {
  if (typeof localStorage !== 'undefined') {
    try {
      localStorage.removeItem(key);
    } catch {
      /* ignore */
    }
  }
  removeLegacySessionStorageItem(key);
}

function migrateFromSessionStorage(key: string): string | null {
  const fromSession = readLegacySessionStorageItem(key);
  if (fromSession == null) {
    return null;
  }
  const write = writeBrowserStorageItem(key, fromSession);
  if (write.ok) {
    removeLegacySessionStorageItem(key);
  }
  return fromSession;
}

function readLegacySessionStorageItem(key: string): string | null {
  if (typeof sessionStorage === 'undefined') {
    return null;
  }
  try {
    return sessionStorage.getItem(key);
  } catch {
    return null;
  }
}

function removeLegacySessionStorageItem(key: string): void {
  if (typeof sessionStorage === 'undefined') {
    return;
  }
  try {
    sessionStorage.removeItem(key);
  } catch {
    /* ignore */
  }
}
