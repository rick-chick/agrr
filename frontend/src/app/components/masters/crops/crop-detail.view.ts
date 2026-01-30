import { Crop } from '../../../domain/crops/crop';

export type CropDetailViewState = {
  loading: boolean;
  error: string | null;
  crop: Crop | null;
};

export interface CropDetailView {
  get control(): CropDetailViewState;
  set control(value: CropDetailViewState);
}
