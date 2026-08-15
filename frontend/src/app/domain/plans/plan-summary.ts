export interface PlanSummary {
  id: number;
  name: string;
  status?: string | null;
  farm_id: number;
  farm_name?: string | null;
  plan_year?: number | null;
}
