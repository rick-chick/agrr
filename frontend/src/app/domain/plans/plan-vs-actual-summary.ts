import type { StageGddCalibrationProposalRaw } from './stage-gdd-calibration-proposal';

export interface PlanVsActualCategorySummary {
  category: string;
  average_delta_days: number | null;
  item_count: number;
  recorded_count: number;
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
}

export interface PlanVsActualSummary {
  plan_id: number;
  unrecorded_count: number;
  categories: PlanVsActualCategorySummary[];
  top_variance_items: PlanVsActualItem[];
  stage_gdd_calibration_proposals?: StageGddCalibrationProposalRaw[];
}

export interface PlanVsActualPlanSummaryStats {
  completedCount: number;
  averageDeltaDays: number | null;
  unrecordedCount: number;
}
