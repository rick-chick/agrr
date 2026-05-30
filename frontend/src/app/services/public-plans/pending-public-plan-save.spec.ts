import { describe, it, expect, beforeEach } from 'vitest';
import {
  consumePendingPublicPlanSave,
  setPendingPublicPlanSave
} from './pending-public-plan-save';

describe('pending-public-plan-save', () => {
  beforeEach(() => {
    sessionStorage.clear();
  });

  it('stores and consumes planId', () => {
    setPendingPublicPlanSave(42);
    const pending = consumePendingPublicPlanSave();
    expect(pending?.planId).toBe(42);
    expect(consumePendingPublicPlanSave()).toBeNull();
  });
});
