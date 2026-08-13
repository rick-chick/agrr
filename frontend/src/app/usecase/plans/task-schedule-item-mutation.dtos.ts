export interface TaskScheduleItemMutationPayload {
  id: number;
  name: string;
  scheduled_date: string | null;
  status: string;
  task_type?: string;
  source?: string;
  agricultural_task_id?: number | null;
  rescheduled_at?: string | null;
  cancelled_at?: string | null;
}

export interface TaskScheduleItemMutationResponse {
  item: TaskScheduleItemMutationPayload;
}
