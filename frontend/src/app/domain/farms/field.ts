export interface Field {
  id: number;
  farm_id: number;
  user_id: number | null;
  name: string;
  description: string | null;
  area: number | null;
  daily_fixed_cost: number | null;
  region: string | null;
  created_at: string;
  updated_at: string;
}
