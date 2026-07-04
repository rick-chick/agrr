import { Crop } from '../../../domain/crops/crop';
import { MastersCropTaskTemplate } from '../../../domain/crops/masters-crop-task-template';
import { CropTaskScheduleBlueprint } from '../../../domain/crops/crop-task-schedule-blueprint';
import { AgriculturalTask } from '../../../domain/agricultural-tasks/agricultural-task';
import { PendingUndoToastRequest } from '../../../core/view-effects/pending-undo-toast-view.effects';
import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';
import { PendingSuccessFlashRequest } from '../../../core/view-effects/pending-success-flash-view.effects';

export type CropDetailViewState = {
  loading: boolean;
  error: string | null;
  crop: Crop | null;
  pendingUndoToast: PendingUndoToastRequest | null;
  pendingErrorFlash: PendingErrorFlashRequest | null;
  pendingSuccessFlash: PendingSuccessFlashRequest | null;

  taskTemplatesLoading: boolean;
  taskTemplates: MastersCropTaskTemplate[];
  agriculturalTasksLoading: boolean;
  agriculturalTasks: AgriculturalTask[];
  unassociatedAgriculturalTasks: AgriculturalTask[];
  selectedAgriculturalTaskId: number | null;
  taskTemplateCreating: boolean;

  blueprintsLoading: boolean;
  blueprints: CropTaskScheduleBlueprint[];
  blueprintsRegenerating: boolean;
  blueprintGddSavingId: number | null;
  blueprintGddDrafts: Record<number, number>;
  blueprintRegenerateError: string | null;

  selectedBlueprintStageOrder: number | null;
  selectedBlueprintAgriculturalTaskId: number | null;
  blueprintCreateGddTrigger: number | null;
  blueprintCreating: boolean;
};

export interface CropDetailView {
  get control(): CropDetailViewState;
  set control(value: CropDetailViewState);
  /** Reload detail (e.g. after undo restore). */
  reload(): void;
}
