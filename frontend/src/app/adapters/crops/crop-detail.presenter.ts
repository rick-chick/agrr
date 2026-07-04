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
  CreateCropTaskTemplateDataDto,
  CreateCropTaskTemplateOutputPort,
  DeleteCropTaskTemplateDataDto,
  DeleteCropTaskTemplateOutputPort,
  LoadCropTaskTemplatesDataDto,
  LoadCropTaskTemplatesOutputPort
} from '../../usecase/crops/crop-task-template.ports';
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
import { AgriculturalTask } from '../../domain/agricultural-tasks/agricultural-task';
import { MastersCropTaskTemplate } from '../../domain/crops/masters-crop-task-template';
import { CropDetailViewState } from '../../components/masters/crops/crop-detail.view';

type BlueprintListDto =
  | LoadCropTaskScheduleBlueprintsDataDto
  | RegenerateCropTaskScheduleBlueprintsDataDto;

function unassociatedAgriculturalTasks(
  templates: MastersCropTaskTemplate[],
  agriculturalTasks: AgriculturalTask[]
): AgriculturalTask[] {
  const associatedIds = new Set(templates.map((t) => t.agricultural_task_id));
  return agriculturalTasks.filter((task) => !associatedIds.has(task.id));
}

function withTaskPickerState(control: CropDetailViewState): CropDetailViewState {
  return {
    ...control,
    unassociatedAgriculturalTasks: unassociatedAgriculturalTasks(
      control.taskTemplates,
      control.agriculturalTasks
    )
  };
}

@Injectable()
export class CropDetailPresenter
  implements
    LoadCropDetailOutputPort,
    DeleteCropOutputPort,
    LoadCropTaskTemplatesOutputPort,
    CreateCropTaskTemplateOutputPort,
    DeleteCropTaskTemplateOutputPort,
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
  present(dto: LoadCropTaskTemplatesDataDto): void;
  present(dto: AgriculturalTaskListDataDto): void;
  present(dto: CreateCropTaskTemplateDataDto): void;
  present(dto: DeleteCropTaskTemplateDataDto): void;
  present(dto: BlueprintListDto): void;
  present(dto: CreateCropTaskScheduleBlueprintDataDto): void;
  present(dto: UpdateCropTaskScheduleBlueprintDataDto): void;
  present(dto: DeleteCropTaskScheduleBlueprintDataDto): void;
  present(
    dto:
      | CropDetailDataDto
      | LoadCropTaskTemplatesDataDto
      | AgriculturalTaskListDataDto
      | CreateCropTaskTemplateDataDto
      | DeleteCropTaskTemplateDataDto
      | BlueprintListDto
      | CreateCropTaskScheduleBlueprintDataDto
      | UpdateCropTaskScheduleBlueprintDataDto
      | DeleteCropTaskScheduleBlueprintDataDto
  ): void {
    if (!this.view) throw new Error('Presenter: view not set');

    if ('crop' in dto) {
      this.view.control = {
        ...this.view.control,
        loading: false,
        error: null,
        crop: dto.crop,
        pendingUndoToast: null,
        pendingErrorFlash: null
      };
      return;
    }

    if ('templates' in dto) {
      this.view.control = withTaskPickerState({
        ...this.view.control,
        taskTemplatesLoading: false,
        taskTemplates: dto.templates
      });
      return;
    }

    if ('tasks' in dto) {
      this.view.control = withTaskPickerState({
        ...this.view.control,
        agriculturalTasksLoading: false,
        agriculturalTasks: dto.tasks
      });
      return;
    }

    if ('template' in dto) {
      const exists = this.view.control.taskTemplates.some((t) => t.id === dto.template.id);
      this.view.control = withTaskPickerState({
        ...this.view.control,
        taskTemplateCreating: false,
        selectedAgriculturalTaskId: null,
        taskTemplates: exists
          ? this.view.control.taskTemplates
          : [...this.view.control.taskTemplates, dto.template],
        pendingErrorFlash: null,
        pendingSuccessFlash: pendingSuccessFlashFromText('crops.agricultural_tasks.flash.template_created')
      });
      return;
    }

    if ('templateId' in dto) {
      this.view.control = withTaskPickerState({
        ...this.view.control,
        taskTemplates: this.view.control.taskTemplates.filter((t) => t.id !== dto.templateId),
        pendingErrorFlash: null,
        pendingSuccessFlash: pendingSuccessFlashFromText('crops.agricultural_tasks.flash.template_deleted')
      });
      return;
    }

    if ('blueprints' in dto) {
      const drafts = Object.fromEntries(dto.blueprints.map((b) => [b.id, b.gdd_trigger]));
      const wasRegenerating = this.view.control.blueprintsRegenerating;
      this.view.control = {
        ...this.view.control,
        blueprintsLoading: false,
        blueprintsRegenerating: false,
        blueprints: dto.blueprints,
        blueprintGddDrafts: drafts,
        blueprintRegenerateError: null,
        pendingErrorFlash: null,
        pendingSuccessFlash: wasRegenerating
          ? pendingSuccessFlashFromText('crops.flash.task_schedule_blueprints_generated')
          : this.view.control.pendingSuccessFlash
      };
      return;
    }

    if ('blueprint' in dto) {
      const exists = this.view.control.blueprints.some((b) => b.id === dto.blueprint.id);
      if (exists) {
        this.view.control = {
          ...this.view.control,
          blueprintGddSavingId: null,
          blueprints: this.view.control.blueprints.map((b) =>
            b.id === dto.blueprint.id ? dto.blueprint : b
          ),
          blueprintGddDrafts: {
            ...this.view.control.blueprintGddDrafts,
            [dto.blueprint.id]: dto.blueprint.gdd_trigger
          },
          pendingErrorFlash: null,
          pendingSuccessFlash: pendingSuccessFlashFromText('crops.flash.blueprint_position_updated')
        };
        return;
      }

      this.view.control = {
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
        blueprintRegenerateError: null,
        pendingErrorFlash: null,
        pendingSuccessFlash: pendingSuccessFlashFromText('crops.flash.blueprint_created')
      };
      return;
    }

    if ('blueprintId' in dto) {
      const { [dto.blueprintId]: _removed, ...remainingDrafts } = this.view.control.blueprintGddDrafts;
      this.view.control = {
        ...this.view.control,
        blueprints: this.view.control.blueprints.filter((b) => b.id !== dto.blueprintId),
        blueprintGddDrafts: remainingDrafts,
        pendingErrorFlash: null,
        pendingSuccessFlash: pendingSuccessFlashFromText('crops.flash.blueprint_deleted')
      };
    }
  }

  onRegenerateStarted(): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      blueprintsRegenerating: true
    };
  }

  onUpdateStarted(blueprintId: number): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      blueprintGddSavingId: blueprintId
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const wasRegenerating = this.view.control.blueprintsRegenerating;
    const inlineBlueprintError =
      wasRegenerating && isBlueprintRegenerateErrorKey(dto.message) ? dto.message : null;
    this.view.control = {
      ...this.view.control,
      loading: false,
      taskTemplatesLoading: false,
      agriculturalTasksLoading: false,
      taskTemplateCreating: false,
      blueprintsLoading: false,
      blueprintsRegenerating: false,
      blueprintGddSavingId: null,
      blueprintCreating: false,
      error: null,
      blueprintRegenerateError: inlineBlueprintError ?? this.view.control.blueprintRegenerateError,
      pendingErrorFlash: inlineBlueprintError ? null : pendingErrorFlashFromError(dto)
    };
  }

  onSuccess(dto: DeleteCropSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (dto.undo) {
      this.view.control = {
        ...this.view.control,
        pendingUndoToast: pendingUndoToastFromDeletion(dto.undo, () =>
          this.listRefreshBus.refresh(LIST_REFRESH_CHANNEL.crops)
        )
      };
    }
  }
}
