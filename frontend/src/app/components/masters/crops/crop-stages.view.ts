import { CropStage } from '../../../domain/crops/crop';
import type { CropTaskScheduleBlueprint } from '../../../domain/crops/crop-task-schedule-blueprint';
import {
  BlueprintGenerationReadiness,
  StageRequirementGap,
  defaultBlueprintReadiness
} from '../../../domain/crops/blueprint-generation-readiness';
import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';
import { PendingSuccessFlashRequest } from '../../../core/view-effects/pending-success-flash-view.effects';

export type CropStagesFormData = {
  name: string;
  is_reference: boolean;
  crop_stages: CropStage[];
};

export type CropStagesViewState = {
  loading: boolean;
  error: string | null;
  formData: CropStagesFormData;
  taskScheduleBlueprints: CropTaskScheduleBlueprint[];
  pendingErrorFlash: PendingErrorFlashRequest | null;
  pendingSuccessFlash: PendingSuccessFlashRequest | null;
  pendingReorderCropStagesSnapshot: CropStage[] | null;
  pendingResyncPanelDraft: boolean;
  blueprintReadiness: BlueprintGenerationReadiness;
  stageRequirementGaps: StageRequirementGap[];
  showBlueprintReadinessChecklist: boolean;
  showNextStepCta: boolean;
};

export { defaultBlueprintReadiness };

export interface CropStagesView {
  get control(): CropStagesViewState;
  set control(value: CropStagesViewState);
  reloadTaskScheduleBlueprints(): void;
}
