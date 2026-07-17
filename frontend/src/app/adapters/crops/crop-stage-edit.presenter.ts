import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import {
  CropStageEditView,
  CropStageEditViewState
} from '../../components/masters/crops/crop-stage-edit.view';
import { LoadCropForEditOutputPort } from '../../usecase/crops/load-crop-for-edit.output-port';
import { LoadCropForEditDataDto } from '../../usecase/crops/load-crop-for-edit.dtos';
import { DeleteCropStageOutputPort } from '../../usecase/crops/delete-crop-stage.output-port';
import { DeleteCropStageOutputDto } from '../../usecase/crops/delete-crop-stage.dtos';
import { pendingErrorFlashFromError } from '../../core/view-effects/pending-error-flash-presenter.helpers';
import { pendingSuccessFlashFromText } from '../../core/view-effects/pending-success-flash-presenter.helpers';
import {
  LoadCropTaskScheduleBlueprintsDataDto,
  LoadCropTaskScheduleBlueprintsOutputPort
} from '../../usecase/crops/crop-task-schedule-blueprint.ports';
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
export class CropStageEditPresenter
  implements
    LoadCropForEditOutputPort,
    LoadCropTaskScheduleBlueprintsOutputPort,
    DeleteCropStageOutputPort,
    SaveCropStagePanelOutputPort,
    SaveCropStageAdvancedDetailsOutputPort
{
  private view: CropStageEditView | null = null;

  setView(view: CropStageEditView): void {
    this.view = view;
  }

  private setControl(control: CropStageEditViewState): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = control;
  }

  present(dto: LoadCropForEditDataDto): void;
  present(dto: LoadCropTaskScheduleBlueprintsDataDto): void;
  present(dto: DeleteCropStageOutputDto): void;
  present(
    dto:
      | LoadCropForEditDataDto
      | LoadCropTaskScheduleBlueprintsDataDto
      | DeleteCropStageOutputDto
  ): void {
    if (!this.view) throw new Error('Presenter: view not set');

    if ('blueprints' in dto) {
      this.setControl({
        ...this.view.control,
        taskScheduleBlueprints: dto.blueprints
      });
      return;
    }

    if ('crop' in dto) {
      const crop = dto.crop;
      this.setControl({
        ...this.view.control,
        loading: false,
        error: null,
        pendingSuccessFlash: null,
        pendingErrorFlash: null,
        pendingNavigateToList: false,
        formData: {
          name: crop.name,
          is_reference: crop.is_reference ?? false,
          crop_stages: crop.crop_stages ?? []
        }
      });
      return;
    }

    if ('success' in dto && 'stageId' in dto) {
      this.presentDeleteCropStage(dto);
    }
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (this.view.control.loading) {
      this.view.control = {
        ...this.view.control,
        loading: false,
        error: dto.message,
        pendingSuccessFlash: null,
        pendingErrorFlash: null,
        pendingNavigateToList: false
      };
      return;
    }

    this.setControl({
      ...this.view.control,
      loading: false,
      error: null,
      pendingSuccessFlash: null,
      pendingErrorFlash: pendingErrorFlashFromError(dto),
      pendingNavigateToList: false
    });
  }

  presentDeleteCropStage(dto: DeleteCropStageOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const currentStages = this.view.control.formData.crop_stages;
    const filteredStages = currentStages.filter((stage) => stage.id !== dto.stageId);
    this.setControl({
      ...this.view.control,
      formData: {
        ...this.view.control.formData,
        crop_stages: filteredStages
      },
      pendingErrorFlash: null,
      pendingSuccessFlash: pendingSuccessFlashFromText('crops.flash.stage_deleted'),
      pendingNavigateToList: true
    });
    this.view.reloadTaskScheduleBlueprints();
  }

  onSuccess(dto: SaveCropStagePanelSuccessDto | SaveCropStageAdvancedDetailsSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const updatedStages = this.view.control.formData.crop_stages.map((stage) =>
      stage.id === dto.stage.id ? dto.stage : stage
    );
    this.setControl({
      ...this.view.control,
      formData: {
        ...this.view.control.formData,
        crop_stages: updatedStages
      },
      pendingErrorFlash: null,
      pendingSuccessFlash: pendingSuccessFlashFromText('crops.flash.stage_updated'),
      pendingResyncPanelDraft: true,
      pendingNavigateToList: false
    });
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
    this.setControl({
      ...this.view.control,
      formData: {
        ...this.view.control.formData,
        name: dto.crop.name,
        crop_stages: dto.crop.crop_stages ?? []
      },
      pendingErrorFlash: pendingErrorFlashFromError({ message: flashKey }),
      pendingSuccessFlash: null,
      pendingResyncPanelDraft: true,
      pendingNavigateToList: false
    });
  }
}
