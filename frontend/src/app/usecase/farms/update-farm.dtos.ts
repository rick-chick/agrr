import { Farm } from '../../domain/farms/farm';

export interface UpdateFarmInputDto {
  farmId: number;
  name: string;
  region: string;
  latitude: number;
  longitude: number;
  onSuccess?: (farm: Farm) => void;
}

export interface UpdateFarmSuccessDto {
  farm: Farm;
}
