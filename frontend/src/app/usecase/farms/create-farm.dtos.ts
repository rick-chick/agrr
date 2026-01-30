import { Farm } from '../../domain/farms/farm';

export interface CreateFarmInputDto {
  name: string;
  region: string;
  latitude: number;
  longitude: number;
  onSuccess?: (farm: Farm) => void;
}

export interface CreateFarmSuccessDto {
  farm: Farm;
}
