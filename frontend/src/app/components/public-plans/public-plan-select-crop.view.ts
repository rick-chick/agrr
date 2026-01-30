import { Crop } from '../../domain/crops/crop';

export type PublicPlanSelectCropViewState = {
  loading: boolean;
  error: string | null;
  crops: Crop[];
  saving: boolean;
};

export interface PublicPlanSelectCropView {
  get control(): PublicPlanSelectCropViewState;
  set control(value: PublicPlanSelectCropViewState);
}
