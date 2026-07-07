import { Crop } from '../../../domain/crops/crop';
import { BlueprintStageLane } from '../../../domain/crops/blueprint-stage-grouping';
import type { BlueprintGddValidationError } from '../../../domain/crops/blueprint-gdd-validation';
import type { CumulativeGddTimelineSegment } from '../../../domain/crops/cumulative-gdd-timeline';
import type { StageCumulativeGddRange } from '../../../domain/crops/stage-cumulative-gdd';
import { CropTaskScheduleBlueprint } from '../../../domain/crops/crop-task-schedule-blueprint';
import { BlueprintGenerationReadiness } from '../../../domain/crops/blueprint-generation-readiness';
import { AgriculturalTask } from '../../../domain/agricultural-tasks/agricultural-task';
import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';
import { PendingSuccessFlashRequest } from '../../../core/view-effects/pending-success-flash-view.effects';

export type CropTaskScheduleBlueprintsViewState = {
  loading: boolean;
  error: string | null;
  crop: Crop | null;
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
  blueprintGddTouched: Record<number, boolean>;
  blueprintStageLanes: BlueprintStageLane[];
  cumulativeGddTimelineSegments: CumulativeGddTimelineSegment[];
  blueprintGddErrors: Record<number, BlueprintGddValidationError | null>;
  blueprintLaneOutOfRangeCounts: Record<number, number>;
  blueprintCreateGddError: BlueprintGddValidationError | null;
  blueprintCreateFormAttempted: boolean;
  selectedStageGddRange: StageCumulativeGddRange | null;
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

export interface CropTaskScheduleBlueprintsView {
  get control(): CropTaskScheduleBlueprintsViewState;
  set control(value: CropTaskScheduleBlueprintsViewState);
  reload(): void;
}
