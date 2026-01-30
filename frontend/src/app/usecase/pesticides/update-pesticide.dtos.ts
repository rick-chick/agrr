import { Pesticide } from '../../domain/pesticides/pesticide';

export interface UpdatePesticideInputDto {
  pesticideId: number;
  name: string;
  active_ingredient: string | null;
  description: string | null;
  crop_id: number;
  pest_id: number;
  region: string | null;
  onSuccess?: (pesticide: Pesticide) => void;
}

export interface UpdatePesticideSuccessDto {
  pesticide: Pesticide;
}