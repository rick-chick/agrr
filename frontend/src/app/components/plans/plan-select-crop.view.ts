import { Farm } from '../../domain/farms/farm';
import { Crop } from '../../domain/crops/crop';

export interface PlanSelectCropViewState {
  loading: boolean;
  error: string | null;
  farm: Farm | null;
  totalArea: number;
  crops: Crop[];
  creating: boolean;
}

export interface PlanSelectCropView {
  control: PlanSelectCropViewState;
  onPlanCreated(planId: number): void;
  onPlanCreateError(error: string): void;
}