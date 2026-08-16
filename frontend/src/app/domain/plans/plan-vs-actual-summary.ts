import type { StageGddCalibrationProposalRaw } from './stage-gdd-calibration-proposal';

export interface PlanVsActualCategorySummary {
  category: string;
  average_delta_days: number | null;
  item_count: number;
  recorded_count: number;
}

export interface PlanVsActualAmountGroupSummary {
  category: string;
  stage_order: number | null;
  stage_name: string | null;
  task_type: string;
  average_amount_delta: number | null;
  recorded_item_count: number;
  amount_unit: string | null;
}

export interface PlanVsActualItem {
  item_id: number;
  field_cultivation_id: number;
  category: string;
  name: string;
  scheduled_date: string | null;
  actual_date: string | null;
  delta_days: number | null;
  gdd_trigger: number | null;
  gdd_at_actual: number | null;
  gdd_delta: number | null;
  amount_planned?: number | null;
  amount_actual?: number | null;
  amount_delta?: number | null;
  amount_unit?: string | null;
}

export type VarianceExceedanceKind = 'days' | 'gdd' | 'both';

export interface PlanVarianceActionItem extends PlanVsActualItem {
  exceedance_kind: VarianceExceedanceKind;
}

export interface PlanVsActualSummary {
  plan_id: number;
  unrecorded_count: number;
  structured_unrecorded_count?: number;
  categories: PlanVsActualCategorySummary[];
  amount_group_summaries?: PlanVsActualAmountGroupSummary[];
  top_variance_items: PlanVsActualItem[];
  stage_gdd_calibration_proposals?: StageGddCalibrationProposalRaw[];
  action_required_items?: PlanVarianceActionItem[];
  blueprint_timing_adjustment_proposals?: import('./blueprint-timing-adjustment-proposal').BlueprintTimingAdjustmentProposalRaw[];
}

export interface PlanVsActualPlanSummaryStats {
  completedCount: number;
  averageDeltaDays: number | null;
  unrecordedCount: number;
}
