/** エントリ作物スケジュール API のレスポンス型（/api/v1/public_plans/entry_schedule/*） */

export interface EntrySchedulePredictionMeta {
  generated_at?: string;
  prediction_start_date?: string;
  prediction_end_date?: string;
  weather_location_id?: number;
  /** チャート横軸「1〜12月」の暦年（サーバの今日基準） */
  chart_calendar_year?: number;
}

export interface EntryScheduleDateRangeSummary {
  start_date: string;
  end_date: string;
}

export interface EntrySchedulePhaseSegment {
  phase_key: string;
  label: string;
  start_date: string | null;
  end_date: string | null;
  empty_reason: string | null;
}

export interface EntryScheduleRoughTimelineItem {
  month: string;
  summary: string;
}

export interface EntryScheduleSortMeta {
  eligible: boolean;
  sowing_proximity_days: number;
  sowing_window_width_days: number;
}

export interface EntryScheduleCropsListMeta {
  total_count: number;
  limit: number;
  next_cursor: string | null;
  has_more: boolean;
}

export interface EntryScheduleCropListItem {
  id: number;
  name: string;
  eligible: boolean;
  sowing_summary: EntryScheduleDateRangeSummary | null;
  transplant_summary: EntryScheduleDateRangeSummary | null;
  reason_summary: string;
  labels: { sowing: string; transplanting: string };
  schedule_flow_summary?: string;
  schedule_flow_detail?: string | null;
  phase_segments?: EntrySchedulePhaseSegment[];
  rough_timeline?: EntryScheduleRoughTimelineItem[];
  sort_meta?: EntryScheduleSortMeta;
}

export interface EntryScheduleCropsListResponse {
  farm: {
    id: number;
    name: string;
    latitude: number;
    longitude: number;
    region: string;
  };
  prediction: EntrySchedulePredictionMeta;
  meta: EntryScheduleCropsListMeta;
  crops: EntryScheduleCropListItem[];
}

export interface EntryScheduleNextTask {
  available: boolean;
  code?: string;
  summary: string | null;
}

export interface EntryScheduleCropDetail extends EntryScheduleCropListItem {
  sowing_windows: EntryScheduleDateRangeSummary[];
  transplant_windows: EntryScheduleDateRangeSummary[];
  reason_parts: Record<string, unknown>;
  sowing_stage_id: number | null;
  transplant_stage_id: number | null;
  crop_stages: Array<{ id: number; name: string; order: number }>;
  entry_disclaimer?: string;
  next_task?: EntryScheduleNextTask;
}

export interface EntryScheduleCropShowResponse {
  farm: EntryScheduleCropsListResponse['farm'];
  prediction: EntrySchedulePredictionMeta;
  crop: EntryScheduleCropDetail;
}
