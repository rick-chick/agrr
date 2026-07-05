import { Crop } from '../../../domain/crops/crop';
import { CropTaskScheduleBlueprint } from '../../../domain/crops/crop-task-schedule-blueprint';
import { BlueprintGenerationReadiness } from '../../../domain/crops/blueprint-generation-readiness';
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

  fromPlanId: number | null;

  agriculturalTasksLoading: boolean;
  agriculturalTasks: AgriculturalTask[];
  unassociatedAgriculturalTasks: AgriculturalTask[];

  blueprintsLoading: boolean;
  blueprints: CropTaskScheduleBlueprint[];
  blueprintsRegenerating: boolean;
  blueprintSavingId: number | null;
  blueprintGddDrafts: Record<number, number | null>;
  blueprintStageDrafts: Record<number, number | null>;
  blueprintRegenerateError: string | null;

  selectedBlueprintStageOrder: number | null;
  selectedBlueprintAgriculturalTaskId: number | null;
  blueprintCreateGddTrigger: number | null;
  blueprintCreating: boolean;

  blueprintReadiness: BlueprintGenerationReadiness;
  canRegenerateBlueprints: boolean;
  canCreateBlueprint: boolean;
  blueprintStageNameForCreate: string | null;
  showBlueprintReadinessChecklist: boolean;
  blueprintSectionDescriptionKey: string;
  showBlueprintEmptyState: boolean;
  showBlueprintRegenerateRetry: boolean;
};

export interface CropDetailView {
  get control(): CropDetailViewState;
  set control(value: CropDetailViewState);
  /** Reload detail (e.g. after undo restore). */
  reload(): void;
}
