export interface Pesticide {
  id: number;
  name: string;
  active_ingredient?: string | null;
  description?: string | null;
  is_reference: boolean;
  crop_id: number;
  pest_id: number;
  region?: string | null;
  crop_name?: string | null;
  pest_name?: string | null;
}
