import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { CropDetailView } from '../../components/masters/crops/crop-detail.view';
import { LoadCropDetailOutputPort } from '../../usecase/crops/load-crop-detail.output-port';
import { CropDetailDataDto } from '../../usecase/crops/load-crop-detail.dtos';
import { DeleteCropOutputPort } from '../../usecase/crops/delete-crop.output-port';
import { DeleteCropSuccessDto } from '../../usecase/crops/delete-crop.dtos';
import { ListRefreshBus } from '../../core/list-refresh/list-refresh-bus.service';
import { LIST_REFRESH_CHANNEL } from '../../core/list-refresh/list-refresh-keys';
import { pendingUndoToastFromDeletion } from '../../core/view-effects/pending-undo-toast-presenter.helpers';
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
import { withCropDetailDisplayState } from '../../core/crops/crop-detail-display-state';

type BlueprintListDto =
  | LoadCropTaskScheduleBlueprintsDataDto
  | RegenerateCropTaskScheduleBlueprintsDataDto;

@Injectable()
export class CropDetailPresenter
  implements
    LoadCropDetailOutputPort,
    DeleteCropOutputPort,
    LoadAgriculturalTaskListOutputPort,
    LoadCropTaskScheduleBlueprintsOutputPort,
    RegenerateCropTaskScheduleBlueprintsOutputPort,
    UpdateCropTaskScheduleBlueprintOutputPort,
    DeleteCropTaskScheduleBlueprintOutputPort,
    CreateCropTaskScheduleBlueprintOutputPort
{
  private readonly listRefreshBus = inject(ListRefreshBus);
  private view: CropDetailView | null = null;

  setView(view: CropDetailView): void {
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
      this.view.control = withCropDetailDisplayState({
        ...this.view.control,
        loading: false,
        error: null,
        crop: dto.crop,
        pendingUndoToast: null,
        pendingErrorFlash: null
      });
      return;
    }

    if ('tasks' in dto) {
      this.view.control = withCropDetailDisplayState({
        ...this.view.control,
        agriculturalTasksLoading: false,
        agriculturalTasks: dto.tasks
      });
      return;
    }

    if ('blueprints' in dto) {
      const drafts = Object.fromEntries(dto.blueprints.map((b) => [b.id, b.gdd_trigger]));
      const stageDrafts = Object.fromEntries(dto.blueprints.map((b) => [b.id, b.stage_order]));
      const wasRegenerating = this.view.control.blueprintsRegenerating;
      this.view.control = withCropDetailDisplayState({
        ...this.view.control,
        blueprintsLoading: false,
        blueprintsRegenerating: false,
        blueprints: dto.blueprints,
        blueprintGddDrafts: drafts,
        blueprintStageDrafts: stageDrafts,
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
        this.view.control = withCropDetailDisplayState({
          ...this.view.control,
          blueprintSavingId: null,
          blueprints: this.view.control.blueprints.map((b) =>
            b.id === dto.blueprint.id ? dto.blueprint : b
          ),
          blueprintGddDrafts: {
            ...this.view.control.blueprintGddDrafts,
            [dto.blueprint.id]: dto.blueprint.gdd_trigger
          },
          blueprintStageDrafts: {
            ...this.view.control.blueprintStageDrafts,
            [dto.blueprint.id]: dto.blueprint.stage_order
          },
          pendingErrorFlash: null,
          pendingSuccessFlash: pendingSuccessFlashFromText('crops.flash.blueprint_position_updated')
        });
        return;
      }

      this.view.control = withCropDetailDisplayState({
        ...this.view.control,
        blueprintCreating: false,
        selectedBlueprintStageOrder: null,
        selectedBlueprintAgriculturalTaskId: null,
        blueprintCreateGddTrigger: null,
        blueprints: [...this.view.control.blueprints, dto.blueprint],
        blueprintGddDrafts: {
          ...this.view.control.blueprintGddDrafts,
          [dto.blueprint.id]: dto.blueprint.gdd_trigger
        },
        blueprintStageDrafts: {
          ...this.view.control.blueprintStageDrafts,
          [dto.blueprint.id]: dto.blueprint.stage_order
        },
        blueprintRegenerateError: null,
        pendingErrorFlash: null,
        pendingSuccessFlash: pendingSuccessFlashFromText('crops.flash.blueprint_created')
      });
      return;
    }

    if ('blueprintId' in dto) {
      const { [dto.blueprintId]: _removedGdd, ...remainingGddDrafts } = this.view.control.blueprintGddDrafts;
      const { [dto.blueprintId]: _removedStage, ...remainingStageDrafts } =
        this.view.control.blueprintStageDrafts;
      this.view.control = withCropDetailDisplayState({
        ...this.view.control,
        blueprints: this.view.control.blueprints.filter((b) => b.id !== dto.blueprintId),
        blueprintGddDrafts: remainingGddDrafts,
        blueprintStageDrafts: remainingStageDrafts,
        pendingErrorFlash: null,
        pendingSuccessFlash: pendingSuccessFlashFromText('crops.flash.blueprint_deleted')
      });
    }
  }

  onRegenerateStarted(): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = withCropDetailDisplayState({
      ...this.view.control,
      blueprintsRegenerating: true
    });
  }

  onUpdateStarted(blueprintId: number): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = withCropDetailDisplayState({
      ...this.view.control,
      blueprintSavingId: blueprintId
    });
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const wasRegenerating = this.view.control.blueprintsRegenerating;
    const inlineBlueprintError =
      wasRegenerating && isBlueprintRegenerateErrorKey(dto.message) ? dto.message : null;
    this.view.control = withCropDetailDisplayState({
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

  onSuccess(dto: DeleteCropSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (dto.undo) {
      this.view.control = withCropDetailDisplayState({
        ...this.view.control,
        pendingUndoToast: pendingUndoToastFromDeletion(dto.undo, () =>
          this.listRefreshBus.refresh(LIST_REFRESH_CHANNEL.crops)
        )
      });
    }
  }
}
