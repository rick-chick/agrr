import { describe, expect, it } from 'vitest';
import {
  buildPlanCarryoverPreviewTableRows,
  countPlanCarryoverPreviewProposals,
  hasPlanCarryoverPreviewTableContent
} from './build-plan-carryover-preview-table-rows';
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

describe('countPlanCarryoverPreviewProposals', () => {
  it('counts GDD calibration and BP timing/amount proposals from summary', () => {
    expect(
      countPlanCarryoverPreviewProposals(
        summary({
          stage_gdd_calibration_proposals: [{ crop_id: 1, stage_id: 2 } as never],
          blueprint_timing_adjustment_proposals: [{ crop_id: 1, category: 'general' } as never],
          blueprint_amount_adjustment_proposals: [
            { crop_id: 1, category: 'general', stage_order: 1 } as never
          ]
        })
      )
    ).toEqual({
      stageGddCount: 1,
      bpTimingCount: 1,
      bpAmountCount: 1
    });
  });
});

describe('buildPlanCarryoverPreviewTableRows', () => {
  it('appends proposal count rows after category rows', () => {
    const rows = buildPlanCarryoverPreviewTableRows(
      summary({
        categories: [
          {
            category: 'task',
            average_delta_days: 1,
            item_count: 2,
            recorded_count: 2
          }
        ],
        stage_gdd_calibration_proposals: [{ crop_id: 1, stage_id: 2 } as never, { crop_id: 1, stage_id: 3 } as never],
        blueprint_timing_adjustment_proposals: [{ crop_id: 1, category: 'general' } as never]
      })
    );

    expect(rows).toHaveLength(3);
    expect(rows[0]).toMatchObject({ kind: 'category', track: 'category:task' });
    expect(rows[1]).toMatchObject({
      kind: 'proposal_count',
      labelKey: 'plans.carryover.preview.stage_gdd_count',
      count: 2
    });
    expect(rows[2]).toMatchObject({
      kind: 'proposal_count',
      labelKey: 'plans.carryover.preview.bp_timing_count',
      count: 1
    });
  });

  it('omits zero-count proposal rows', () => {
    const rows = buildPlanCarryoverPreviewTableRows(
      summary({
        blueprint_amount_adjustment_proposals: [
          { crop_id: 1, category: 'general', stage_order: 1 } as never
        ]
      })
    );

    expect(rows).toEqual([
      {
        kind: 'proposal_count',
        track: 'proposal:bp_amount',
        labelKey: 'plans.carryover.preview.bp_amount_count',
        count: 1
      }
    ]);
  });
});

describe('hasPlanCarryoverPreviewTableContent', () => {
  it('is true when categories or proposal counts exist', () => {
    expect(hasPlanCarryoverPreviewTableContent(summary())).toBe(false);
    expect(
      hasPlanCarryoverPreviewTableContent(
        summary({ stage_gdd_calibration_proposals: [{ crop_id: 1, stage_id: 2 } as never] })
      )
    ).toBe(true);
  });
});
