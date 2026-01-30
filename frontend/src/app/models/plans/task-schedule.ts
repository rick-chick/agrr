export interface PlanInfo {
  id: number;
  name: string;
  status: string;
  planning_start_date: string;
  planning_end_date: string;
  timeline_generated_at: string;
  timeline_generated_at_display: string;
}

export interface WeekInfo {
  start_date: string;
  end_date: string;
  label: string;
  days: DayInfo[];
}

export interface DayInfo {
  date: string;
  weekday: string;
  is_today: boolean;
}

export interface TaskOption {
  template_id: number;
  name: string;
  task_type: string;
  agricultural_task_id: number;
  description: string;
  weather_dependency: string;
  time_per_sqm: string;
  required_tools: string[];
  skill_level: string;
}

export interface TaskDetails {
  stage: {
    name: string;
    order: number;
  };
  gdd: {
    trigger: string;
    tolerance: string;
  };
  priority: number;
  weather_dependency: string;
  time_per_sqm: string;
  amount: string;
  amount_unit: string;
  source: string;
  master: {
    name: string;
    description: string;
    time_per_sqm: string;
    weather_dependency: string;
    required_tools: string[];
    skill_level: string;
    task_type: string;
  } | null;
  actual: {
    date: string | null;
    notes: string | null;
  };
  history: {
    rescheduled_at: string | null;
    cancelled_at: string | null;
    completed_at: string | null;
  };
}

export interface TaskBadge {
  type: string;
  priority_level: string;
  status: string;
  category: string;
}

export interface TaskScheduleItem {
  item_id: number;
  name: string;
  task_type: string;
  category: string;
  scheduled_date: string | null;
  stage_name: string;
  stage_order: number;
  gdd_trigger: string;
  gdd_tolerance: string;
  priority: number;
  source: string;
  weather_dependency: string;
  time_per_sqm: string;
  amount: string;
  amount_unit: string;
  status: string;
  agricultural_task_id: number;
  field_cultivation_id: number;
  details: TaskDetails;
  badge: TaskBadge;
}

export interface FieldSchedule {
  id: number;
  name: string;
  crop_name: string;
  area_sqm: number;
  field_cultivation_id: number;
  crop_id: number;
  task_options: TaskOption[];
  schedules: {
    general: TaskScheduleItem[];
    fertilizer: TaskScheduleItem[];
    unscheduled: TaskScheduleItem[];
  };
}

export interface TaskScheduleResponse {
  plan: PlanInfo;
  week: WeekInfo;
  milestones: any[];
  fields: FieldSchedule[];
  labels: any;
  minimap: any;
}
