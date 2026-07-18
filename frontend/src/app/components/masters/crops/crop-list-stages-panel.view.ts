import { Crop } from '../../../domain/crops/crop';

export type CropListStagesPanelViewState = {
  loading: boolean;
  error: string | null;
  crop: Crop | null;
};

export interface CropListStagesPanelView {
  get control(): CropListStagesPanelViewState;
  set control(value: CropListStagesPanelViewState);
}
