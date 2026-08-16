import type { PlanVsActualCategorySummary, PlanVsActualSummary } from './plan-vs-actual-summary';

export type PlanCarryoverPreviewTableRow =
  | {
      kind: 'category';
      track: string;
      category: PlanVsActualCategorySummary;
    }
  | {
      kind: 'proposal_count';
      track: string;
      labelKey: string;
      count: number;
    };

export function countPlanCarryoverPreviewProposals(summary: PlanVsActualSummary): {
  stageGddCount: number;
  bpTimingCount: number;
  bpAmountCount: number;
} {
  return {
    stageGddCount: summary.stage_gdd_calibration_proposals?.length ?? 0,
    bpTimingCount: summary.blueprint_timing_adjustment_proposals?.length ?? 0,
    bpAmountCount: summary.blueprint_amount_adjustment_proposals?.length ?? 0
  };
}

export function buildPlanCarryoverPreviewTableRows(
  summary: PlanVsActualSummary
): PlanCarryoverPreviewTableRow[] {
  const rows: PlanCarryoverPreviewTableRow[] = summary.categories.map((category) => ({
    kind: 'category',
    track: `category:${category.category}`,
    category
  }));

  const counts = countPlanCarryoverPreviewProposals(summary);
  if (counts.stageGddCount > 0) {
    rows.push({
      kind: 'proposal_count',
      track: 'proposal:stage_gdd',
      labelKey: 'plans.carryover.preview.stage_gdd_count',
      count: counts.stageGddCount
    });
  }
  if (counts.bpTimingCount > 0) {
    rows.push({
      kind: 'proposal_count',
      track: 'proposal:bp_timing',
      labelKey: 'plans.carryover.preview.bp_timing_count',
      count: counts.bpTimingCount
    });
  }
  if (counts.bpAmountCount > 0) {
    rows.push({
      kind: 'proposal_count',
      track: 'proposal:bp_amount',
      labelKey: 'plans.carryover.preview.bp_amount_count',
      count: counts.bpAmountCount
    });
  }

  return rows;
}

export function hasPlanCarryoverPreviewTableContent(summary: PlanVsActualSummary): boolean {
  return buildPlanCarryoverPreviewTableRows(summary).length > 0;
}
