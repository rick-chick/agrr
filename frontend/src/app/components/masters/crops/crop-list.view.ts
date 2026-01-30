import { Crop } from '../../../domain/crops/crop';

export type CropListViewState = {
  loading: boolean;
  error: string | null;
  crops: Crop[];
};

export interface CropListView {
  get control(): CropListViewState;
  set control(value: CropListViewState);
}
