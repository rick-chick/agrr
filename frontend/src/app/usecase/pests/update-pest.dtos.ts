import { Pest } from '../../domain/pests/pest';

export interface UpdatePestInputDto {
  pestId: number;
  name: string;
  name_scientific: string | null;
  family: string | null;
  order: string | null;
  description: string | null;
  occurrence_season: string | null;
  region: string | null;
  onSuccess?: (pest: Pest) => void;
}

export interface UpdatePestSuccessDto {
  pest: Pest;
}