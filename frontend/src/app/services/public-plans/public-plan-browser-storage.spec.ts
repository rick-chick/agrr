import { describe, it, expect, beforeEach } from 'vitest';
import {
  PENDING_PUBLIC_PLAN_SAVE_STORAGE_KEY,
  PUBLIC_PLAN_STATE_STORAGE_KEY,
  readBrowserStorageItem,
  removeBrowserStorageItem,
  writeBrowserStorageItem
} from './public-plan-browser-storage';

describe('public-plan-browser-storage', () => {
  beforeEach(() => {
    localStorage.clear();
    sessionStorage.clear();
  });

  it('persists values in localStorage', () => {
    const result = writeBrowserStorageItem(PUBLIC_PLAN_STATE_STORAGE_KEY, '{"farm":null}');

    expect(result).toEqual({ ok: true });
    expect(localStorage.getItem(PUBLIC_PLAN_STATE_STORAGE_KEY)).toBe('{"farm":null}');
  });

  it('migrates legacy sessionStorage entries into localStorage on read', () => {
    sessionStorage.setItem(PUBLIC_PLAN_STATE_STORAGE_KEY, '{"farm":{"id":2}}');

    expect(readBrowserStorageItem(PUBLIC_PLAN_STATE_STORAGE_KEY)).toBe('{"farm":{"id":2}}');
    expect(localStorage.getItem(PUBLIC_PLAN_STATE_STORAGE_KEY)).toBe('{"farm":{"id":2}}');
    expect(sessionStorage.getItem(PUBLIC_PLAN_STATE_STORAGE_KEY)).toBeNull();
  });

  it('removes pending save from both storages', () => {
    localStorage.setItem(PENDING_PUBLIC_PLAN_SAVE_STORAGE_KEY, '{"planId":1}');
    sessionStorage.setItem(PENDING_PUBLIC_PLAN_SAVE_STORAGE_KEY, '{"planId":1}');

    removeBrowserStorageItem(PENDING_PUBLIC_PLAN_SAVE_STORAGE_KEY);

    expect(localStorage.getItem(PENDING_PUBLIC_PLAN_SAVE_STORAGE_KEY)).toBeNull();
    expect(sessionStorage.getItem(PENDING_PUBLIC_PLAN_SAVE_STORAGE_KEY)).toBeNull();
  });
});
