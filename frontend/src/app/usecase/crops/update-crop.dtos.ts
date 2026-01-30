import { Crop } from '../../domain/crops/crop';

export interface UpdateCropInputDto {
  cropId: number;
  name: string;
  variety: string | null;
  area_per_unit: number | null;
  revenue_per_area: number | null;
  region: string | null;
  groups: string[];
  onSuccess?: (crop: Crop) => void;
}

export interface UpdateCropSuccessDto {
  crop: Crop;
}
