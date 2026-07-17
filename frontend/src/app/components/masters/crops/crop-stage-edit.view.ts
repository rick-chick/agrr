import type { CropTaskScheduleBlueprint } from '../../../domain/crops/crop-task-schedule-blueprint';
import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';
import { PendingSuccessFlashRequest } from '../../../core/view-effects/pending-success-flash-view.effects';
import { CropStagesFormData } from './crop-stages.view';

export type CropStageEditViewState = {
  loading: boolean;
  error: string | null;
  formData: CropStagesFormData;
  taskScheduleBlueprints: CropTaskScheduleBlueprint[];
  pendingErrorFlash: PendingErrorFlashRequest | null;
  pendingSuccessFlash: PendingSuccessFlashRequest | null;
  pendingResyncPanelDraft: boolean;
  pendingNavigateToList: boolean;
};

export interface CropStageEditView {
  get control(): CropStageEditViewState;
  set control(value: CropStageEditViewState);
  reloadTaskScheduleBlueprints(): void;
}
