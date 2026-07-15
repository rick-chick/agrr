import { CropStage } from '../../../domain/crops/crop';
import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';
import { PendingSuccessFlashRequest } from '../../../core/view-effects/pending-success-flash-view.effects';
import {
  BlueprintGenerationReadiness,
  defaultBlueprintReadiness
} from '../../../domain/crops/blueprint-generation-readiness';

export type CropStagesFormData = {
  name: string;
  crop_stages: CropStage[];
};

export type CropStagesViewState = {
  loading: boolean;
  error: string | null;
  formData: CropStagesFormData;
  blueprintReadiness: BlueprintGenerationReadiness;
  pendingErrorFlash: PendingErrorFlashRequest | null;
  pendingSuccessFlash: PendingSuccessFlashRequest | null;
};

export interface CropStagesView {
  get control(): CropStagesViewState;
  set control(value: CropStagesViewState);
}
