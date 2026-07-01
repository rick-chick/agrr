import { describe, expect, it, vi } from 'vitest';
import { applyTaskScheduleSyncViewEffects } from './task-schedule-sync-view.effects';

describe('applyTaskScheduleSyncViewEffects', () => {
  it('reloads when syncReloadNonce increments', () => {
    const toast = { show: vi.fn() };
    const translate = { instant: vi.fn() };
    const onReload = vi.fn();

    const prev = { pendingSyncToastKey: null, syncReloadNonce: 1 };
    const next = { pendingSyncToastKey: null, syncReloadNonce: 2 };

    applyTaskScheduleSyncViewEffects(prev, next, { toast, translate, onReload });

    expect(onReload).toHaveBeenCalled();
  });
});
