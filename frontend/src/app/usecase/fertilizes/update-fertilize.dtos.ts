import { Fertilize } from '../../domain/fertilizes/fertilize';

export interface UpdateFertilizeInputDto {
  fertilizeId: number;
  name: string;
  n: number | null;
  p: number | null;
  k: number | null;
  description: string | null;
  package_size: number | null;
  region: string | null;
  onSuccess?: (fertilize: Fertilize) => void;
}

export interface UpdateFertilizeSuccessDto {
  fertilize: Fertilize;
}
