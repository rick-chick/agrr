import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { CropStagesView } from '../../components/masters/crops/crop-stages.view';
import { LoadCropForEditOutputPort } from '../../usecase/crops/load-crop-for-edit.output-port';
import { LoadCropForEditDataDto } from '../../usecase/crops/load-crop-for-edit.dtos';
import { CreateCropStageOutputPort } from '../../usecase/crops/create-crop-stage.output-port';
import { CreateCropStageOutputDto } from '../../usecase/crops/create-crop-stage.dtos';
import { ReorderCropStagesOutputPort } from '../../usecase/crops/reorder-crop-stages.output-port';
import { ReorderCropStagesOutputDto } from '../../usecase/crops/reorder-crop-stages.dtos';
import { DeleteCropStageOutputPort } from '../../usecase/crops/delete-crop-stage.output-port';
import { DeleteCropStageOutputDto } from '../../usecase/crops/delete-crop-stage.dtos';
import { pendingErrorFlashFromError } from '../../core/view-effects/pending-error-flash-presenter.helpers';
import { pendingSuccessFlashFromText } from '../../core/view-effects/pending-success-flash-presenter.helpers';
import { LoadCropTaskScheduleBlueprintsDataDto } from '../../usecase/crops/crop-task-schedule-blueprint.ports';
import { LoadCropTaskScheduleBlueprintsOutputPort } from '../../usecase/crops/crop-task-schedule-blueprint.ports';
import { SaveCropStagePanelOutputPort } from '../../usecase/crops/save-crop-stage-panel.output-port';
import {
  SaveCropStagePanelPartialFailureDto,
  SaveCropStagePanelSuccessDto
} from '../../usecase/crops/save-crop-stage-panel.dtos';
import { SaveCropStageAdvancedDetailsOutputPort } from '../../usecase/crops/save-crop-stage-advanced-details.output-port';
import {
  SaveCropStageAdvancedDetailsPartialFailureDto,
  SaveCropStageAdvancedDetailsSuccessDto
} from '../../usecase/crops/save-crop-stage-advanced-details.dtos';

@Injectable()
export class CropStagesPresenter implements
  LoadCropForEditOutputPort,
  LoadCropTaskScheduleBlueprintsOutputPort,
  CreateCropStageOutputPort,
  ReorderCropStagesOutputPort,
  DeleteCropStageOutputPort,
  SaveCropStagePanelOutputPort,
  SaveCropStageAdvancedDetailsOutputPort {
  private view: CropStagesView | null = null;

  setView(view: CropStagesView): void {
    this.view = view;
  }

  present(dto: LoadCropForEditDataDto): void;
  present(dto: LoadCropTaskScheduleBlueprintsDataDto): void;
  present(dto: CreateCropStageOutputDto | ReorderCropStagesOutputDto | DeleteCropStageOutputDto): void;
  present(dto: LoadCropForEditDataDto | LoadCropTaskScheduleBlueprintsDataDto | CreateCropStageOutputDto | ReorderCropStagesOutputDto | DeleteCropStageOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');

    if ('blueprints' in dto) {
      this.view.control = {
        ...this.view.control,
        taskScheduleBlueprints: dto.blueprints
      };
      return;
    }

    if ('crop' in dto) {
      const crop = (dto as LoadCropForEditDataDto).crop;
      this.view.control = {
        ...this.view.control,
        loading: false,
        error: null,
        pendingSuccessFlash: null,
        pendingErrorFlash: null,
        pendingReorderCropStagesSnapshot: null,
        formData: {
          name: crop.name,
          crop_stages: crop.crop_stages ?? []
        }
      };
      return;
    }

    if ('stages' in dto && Array.isArray((dto as ReorderCropStagesOutputDto).stages)) {
      this.presentReorderCropStages(dto as ReorderCropStagesOutputDto);
      return;
    }

    if ('stage' in dto && !('success' in dto)) {
      this.presentCreateCropStage(dto as CreateCropStageOutputDto);
    } else if ('success' in dto && 'stageId' in dto) {
      this.presentDeleteCropStage(dto as DeleteCropStageOutputDto);
    }
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const snapshot = this.view.control.pendingReorderCropStagesSnapshot;
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      pendingSuccessFlash: null,
      pendingErrorFlash: pendingErrorFlashFromError(dto),
      pendingReorderCropStagesSnapshot: null,
      formData: snapshot
        ? {
            ...this.view.control.formData,
            crop_stages: snapshot
          }
        : this.view.control.formData
    };
  }

  presentCreateCropStage(dto: CreateCropStageOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const currentStages = this.view.control.formData.crop_stages;
    this.view.control = {
      ...this.view.control,
      formData: {
        ...this.view.control.formData,
        crop_stages: [...currentStages, dto.stage]
      },
      pendingErrorFlash: null,
      pendingSuccessFlash: pendingSuccessFlashFromText('crops.flash.stage_created')
    };
  }

  presentReorderCropStages(dto: ReorderCropStagesOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const byId = new Map(dto.stages.map((stage) => [stage.id, stage]));
    const updatedStages = this.view.control.formData.crop_stages.map((stage) => byId.get(stage.id) ?? stage);
    this.view.control = {
      ...this.view.control,
      formData: {
        ...this.view.control.formData,
        crop_stages: updatedStages
      },
      pendingReorderCropStagesSnapshot: null,
      pendingErrorFlash: null,
      pendingSuccessFlash: pendingSuccessFlashFromText('crops.flash.stage_updated')
    };
  }

  presentDeleteCropStage(dto: DeleteCropStageOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const currentStages = this.view.control.formData.crop_stages;
    const filteredStages = currentStages.filter(stage => stage.id !== dto.stageId);
    this.view.control = {
      ...this.view.control,
      formData: {
        ...this.view.control.formData,
        crop_stages: filteredStages
      },
      pendingErrorFlash: null,
      pendingSuccessFlash: pendingSuccessFlashFromText('crops.flash.stage_deleted')
    };
  }

  onSuccess(dto: SaveCropStagePanelSuccessDto | SaveCropStageAdvancedDetailsSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const updatedStages = this.view.control.formData.crop_stages.map((stage) =>
      stage.id === dto.stage.id ? dto.stage : stage
    );
    this.view.control = {
      ...this.view.control,
      formData: {
        ...this.view.control.formData,
        crop_stages: updatedStages
      },
      pendingErrorFlash: null,
      pendingSuccessFlash: pendingSuccessFlashFromText('crops.flash.stage_updated')
    };
  }

  onPanelPartialFailure(dto: SaveCropStagePanelPartialFailureDto): void {
    this.presentPartialSaveFailure(dto, 'crops.flash.stage_panel_partial_save_failed');
  }

  onAdvancedPartialFailure(dto: SaveCropStageAdvancedDetailsPartialFailureDto): void {
    this.presentPartialSaveFailure(dto, 'crops.flash.stage_advanced_partial_save_failed');
  }

  private presentPartialSaveFailure(
    dto: SaveCropStagePanelPartialFailureDto | SaveCropStageAdvancedDetailsPartialFailureDto,
    flashKey: string
  ): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      formData: {
        ...this.view.control.formData,
        name: dto.crop.name,
        crop_stages: dto.crop.crop_stages ?? []
      },
      pendingSuccessFlash: null,
      pendingErrorFlash: pendingErrorFlashFromError({ message: flashKey })
    };
  }
}
