import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { CropTaskScheduleBlueprintsView } from '../../components/masters/crops/crop-task-schedule-blueprints.view';
import { LoadCropDetailOutputPort } from '../../usecase/crops/load-crop-detail.output-port';
import { CropDetailDataDto } from '../../usecase/crops/load-crop-detail.dtos';
import { pendingErrorFlashFromError } from '../../core/view-effects/pending-error-flash-presenter.helpers';
import { pendingSuccessFlashFromText } from '../../core/view-effects/pending-success-flash-presenter.helpers';
import { isBlueprintRegenerateErrorKey } from '../../core/crop-blueprint-regenerate-error-i18n';
import {
  CreateCropTaskScheduleBlueprintDataDto,
  CreateCropTaskScheduleBlueprintOutputPort,
  DeleteCropTaskScheduleBlueprintDataDto,
  DeleteCropTaskScheduleBlueprintOutputPort,
  LoadCropTaskScheduleBlueprintsDataDto,
  LoadCropTaskScheduleBlueprintsOutputPort,
  RegenerateCropTaskScheduleBlueprintsDataDto,
  RegenerateCropTaskScheduleBlueprintsOutputPort,
  UpdateCropTaskScheduleBlueprintDataDto,
  UpdateCropTaskScheduleBlueprintOutputPort
} from '../../usecase/crops/crop-task-schedule-blueprint.ports';
import { LoadAgriculturalTaskListOutputPort } from '../../usecase/agricultural-tasks/load-agricultural-task-list.output-port';
import { AgriculturalTaskListDataDto } from '../../usecase/agricultural-tasks/load-agricultural-task-list.dtos';
import { withCropBlueprintDisplayState } from './crop-blueprints-display-state';
import { blueprintGddDraftsFromBlueprints } from '../../domain/crops/blueprint-gdd-coordinates';
import { CropTaskScheduleBlueprintsViewState } from '../../components/masters/crops/crop-task-schedule-blueprints.view';

type BlueprintListDto =
  | LoadCropTaskScheduleBlueprintsDataDto
  | RegenerateCropTaskScheduleBlueprintsDataDto;

@Injectable()
export class CropTaskScheduleBlueprintsPresenter
  implements
    LoadCropDetailOutputPort,
    LoadAgriculturalTaskListOutputPort,
    LoadCropTaskScheduleBlueprintsOutputPort,
    RegenerateCropTaskScheduleBlueprintsOutputPort,
    UpdateCropTaskScheduleBlueprintOutputPort,
    DeleteCropTaskScheduleBlueprintOutputPort,
    CreateCropTaskScheduleBlueprintOutputPort
{
  private view: CropTaskScheduleBlueprintsView | null = null;

  setView(view: CropTaskScheduleBlueprintsView): void {
    this.view = view;
  }

  present(dto: CropDetailDataDto): void;
  present(dto: AgriculturalTaskListDataDto): void;
  present(dto: BlueprintListDto): void;
  present(dto: CreateCropTaskScheduleBlueprintDataDto): void;
  present(dto: UpdateCropTaskScheduleBlueprintDataDto): void;
  present(dto: DeleteCropTaskScheduleBlueprintDataDto): void;
  present(
    dto:
      | CropDetailDataDto
      | AgriculturalTaskListDataDto
      | BlueprintListDto
      | CreateCropTaskScheduleBlueprintDataDto
      | UpdateCropTaskScheduleBlueprintDataDto
      | DeleteCropTaskScheduleBlueprintDataDto
  ): void {
    if (!this.view) throw new Error('Presenter: view not set');

    if ('crop' in dto) {
      this.view.control = withCropBlueprintDisplayState({
        ...this.view.control,
        loading: false,
        error: null,
        crop: dto.crop,
        pendingErrorFlash: null
      });
      return;
    }

    if ('tasks' in dto) {
      this.view.control = withCropBlueprintDisplayState({
        ...this.view.control,
        agriculturalTasksLoading: false,
        agriculturalTasks: dto.tasks
      });
      return;
    }

    if ('blueprints' in dto) {
      const drafts = blueprintGddDraftsFromBlueprints(dto.blueprints);
      const wasRegenerating = this.view.control.blueprintsRegenerating;
      this.view.control = withCropBlueprintDisplayState({
        ...this.view.control,
        blueprintsLoading: false,
        blueprintsRegenerating: false,
        blueprints: dto.blueprints,
        blueprintGddDrafts: drafts,
        blueprintGddTouched: {},
        blueprintRegenerateError: null,
        pendingErrorFlash: null,
        pendingSuccessFlash: wasRegenerating
          ? pendingSuccessFlashFromText('crops.flash.task_schedule_blueprints_generated')
          : this.view.control.pendingSuccessFlash
      });
      return;
    }

    if ('blueprint' in dto) {
      const exists = this.view.control.blueprints.some((b) => b.id === dto.blueprint.id);
      if (exists) {
        this.view.control = withCropBlueprintDisplayState({
          ...this.view.control,
          blueprintSavingId: null,
          blueprints: this.view.control.blueprints.map((b) =>
            b.id === dto.blueprint.id ? dto.blueprint : b
          ),
          blueprintGddDrafts: {
            ...this.view.control.blueprintGddDrafts,
            [dto.blueprint.id]: dto.blueprint.gdd_trigger
          },
          blueprintGddTouched: {
            ...this.view.control.blueprintGddTouched,
            [dto.blueprint.id]: false
          },
          pendingErrorFlash: null,
          pendingSuccessFlash: pendingSuccessFlashFromText('crops.flash.blueprint_position_updated')
        });
        return;
      }

      this.view.control = withCropBlueprintDisplayState({
        ...this.view.control,
        blueprintCreating: false,
        selectedBlueprintStageOrder: null,
        selectedBlueprintAgriculturalTaskId: null,
        blueprintCreateGddTrigger: null,
        blueprintCreateFormAttempted: false,
        blueprints: [...this.view.control.blueprints, dto.blueprint],
        blueprintGddDrafts: {
          ...this.view.control.blueprintGddDrafts,
          [dto.blueprint.id]: dto.blueprint.gdd_trigger
        },
        blueprintGddTouched: {
          ...this.view.control.blueprintGddTouched,
          [dto.blueprint.id]: false
        },
        blueprintRegenerateError: null,
        pendingErrorFlash: null,
        pendingSuccessFlash: pendingSuccessFlashFromText('crops.flash.blueprint_created')
      });
      return;
    }

    if ('blueprintId' in dto) {
      const { [dto.blueprintId]: _removedGdd, ...remainingGddDrafts } = this.view.control.blueprintGddDrafts;
      const { [dto.blueprintId]: _removedTouched, ...remainingTouched } =
        this.view.control.blueprintGddTouched;
      this.view.control = withCropBlueprintDisplayState({
        ...this.view.control,
        blueprints: this.view.control.blueprints.filter((b) => b.id !== dto.blueprintId),
        blueprintGddDrafts: remainingGddDrafts,
        blueprintGddTouched: remainingTouched,
        pendingErrorFlash: null,
        pendingSuccessFlash: pendingSuccessFlashFromText('crops.flash.blueprint_deleted')
      });
    }
  }

  onRegenerateStarted(): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = withCropBlueprintDisplayState({
      ...this.view.control,
      blueprintsRegenerating: true
    });
  }

  onUpdateStarted(blueprintId: number): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = withCropBlueprintDisplayState({
      ...this.view.control,
      blueprintSavingId: blueprintId
    });
  }

  applyLocalControl(patch: Partial<CropTaskScheduleBlueprintsViewState>): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = withCropBlueprintDisplayState({
      ...this.view.control,
      ...patch
    });
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const wasRegenerating = this.view.control.blueprintsRegenerating;
    const inlineBlueprintError =
      wasRegenerating && isBlueprintRegenerateErrorKey(dto.message) ? dto.message : null;
    this.view.control = withCropBlueprintDisplayState({
      ...this.view.control,
      loading: false,
      agriculturalTasksLoading: false,
      blueprintsLoading: false,
      blueprintsRegenerating: false,
      blueprintSavingId: null,
      blueprintCreating: false,
      error: null,
      blueprintRegenerateError: inlineBlueprintError ?? this.view.control.blueprintRegenerateError,
      pendingErrorFlash: inlineBlueprintError ? null : pendingErrorFlashFromError(dto)
    });
  }
}
