import { describe, it, expect, beforeEach } from 'vitest';
import {
  clearPendingPublicPlanSave,
  peekPendingPublicPlanSave,
  setPendingPublicPlanSave
} from './pending-public-plan-save';
import { PENDING_PUBLIC_PLAN_SAVE_STORAGE_KEY } from './public-plan-browser-storage';

describe('pending-public-plan-save', () => {
  beforeEach(() => {
    localStorage.clear();
    sessionStorage.clear();
  });

  it('stores and peeks planId without removing it', () => {
    expect(setPendingPublicPlanSave(42)).toBe(true);

    const pending = peekPendingPublicPlanSave();

    expect(pending?.planId).toBe(42);
    expect(localStorage.getItem(PENDING_PUBLIC_PLAN_SAVE_STORAGE_KEY)).toContain('"planId":42');
  });

  it('clears pending save only after explicit clear', () => {
    setPendingPublicPlanSave(42);

    clearPendingPublicPlanSave();

    expect(peekPendingPublicPlanSave()).toBeNull();
  });

  it('returns false when localStorage is unavailable', () => {
    const originalLocalStorage = globalThis.localStorage;
    Object.defineProperty(globalThis, 'localStorage', {
      configurable: true,
      value: undefined
    });

    expect(setPendingPublicPlanSave(42)).toBe(false);

    Object.defineProperty(globalThis, 'localStorage', {
      configurable: true,
      value: originalLocalStorage
    });
  });
});
