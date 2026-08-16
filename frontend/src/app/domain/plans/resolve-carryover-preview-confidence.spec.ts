import { describe, expect, it } from 'vitest';
import { resolveCarryoverPreviewConfidence } from './resolve-carryover-preview-confidence';
import type { PlanVsActualSummary } from './plan-vs-actual-summary';

function summary(overrides: Partial<PlanVsActualSummary> = {}): PlanVsActualSummary {
  return {
    plan_id: 7,
    unrecorded_count: 0,
    categories: [],
    top_variance_items: [],
    ...overrides
  };
}

describe('resolveCarryoverPreviewConfidence', () => {
  it('returns low when unrecorded tasks remain on source plan', () => {
    expect(resolveCarryoverPreviewConfidence(summary({ unrecorded_count: 2 }))).toBe('low');
  });

  it('returns medium when action-required items exist without unrecorded tasks', () => {
    expect(
      resolveCarryoverPreviewConfidence(
        summary({
          action_required_items: [{ item_id: 1 } as never]
        })
      )
    ).toBe('medium');
  });

  it('returns high when variance data is complete', () => {
    expect(resolveCarryoverPreviewConfidence(summary())).toBe('high');
  });
});
