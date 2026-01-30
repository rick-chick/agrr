export interface Pest {
  id: number;
  name: string;
  name_scientific?: string | null;
  family?: string | null;
  order?: string | null;
  description?: string | null;
  occurrence_season?: string | null;
  is_reference: boolean;
  region?: string | null;
}
