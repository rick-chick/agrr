import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { CropStagesView } from '../../components/masters/crops/crop-stages.view';
import { LoadCropForEditOutputPort } from '../../usecase/crops/load-crop-for-edit.output-port';
import { LoadCropForEditDataDto } from '../../usecase/crops/load-crop-for-edit.dtos';
import { CreateCropStageOutputPort } from '../../usecase/crops/create-crop-stage.output-port';
import { CreateCropStageOutputDto } from '../../usecase/crops/create-crop-stage.dtos';
import { UpdateCropStageOutputPort } from '../../usecase/crops/update-crop-stage.output-port';
import { UpdateCropStageOutputDto } from '../../usecase/crops/update-crop-stage.dtos';
import { DeleteCropStageOutputPort } from '../../usecase/crops/delete-crop-stage.output-port';
import { DeleteCropStageOutputDto } from '../../usecase/crops/delete-crop-stage.dtos';
import { UpdateTemperatureRequirementOutputPort } from '../../usecase/crops/update-temperature-requirement.output-port';
import { UpdateTemperatureRequirementOutputDto } from '../../usecase/crops/update-temperature-requirement.dtos';
import { UpdateThermalRequirementOutputPort } from '../../usecase/crops/update-thermal-requirement.output-port';
import { UpdateThermalRequirementOutputDto } from '../../usecase/crops/update-thermal-requirement.dtos';
import { UpdateSunshineRequirementOutputPort } from '../../usecase/crops/update-sunshine-requirement.output-port';
import { UpdateSunshineRequirementOutputDto } from '../../usecase/crops/update-sunshine-requirement.dtos';
import { UpdateNutrientRequirementOutputPort } from '../../usecase/crops/update-nutrient-requirement.output-port';
import { UpdateNutrientRequirementOutputDto } from '../../usecase/crops/update-nutrient-requirement.dtos';
import { pendingErrorFlashFromError } from '../../core/view-effects/pending-error-flash-presenter.helpers';
import { pendingSuccessFlashFromText } from '../../core/view-effects/pending-success-flash-presenter.helpers';

@Injectable()
export class CropStagesPresenter implements
  LoadCropForEditOutputPort,
  CreateCropStageOutputPort,
  UpdateCropStageOutputPort,
  DeleteCropStageOutputPort,
  UpdateTemperatureRequirementOutputPort,
  UpdateThermalRequirementOutputPort,
  UpdateSunshineRequirementOutputPort,
  UpdateNutrientRequirementOutputPort {
  private view: CropStagesView | null = null;

  setView(view: CropStagesView): void {
    this.view = view;
  }

  present(dto: LoadCropForEditDataDto): void;
  present(dto: CreateCropStageOutputDto | UpdateCropStageOutputDto | DeleteCropStageOutputDto | UpdateTemperatureRequirementOutputDto | UpdateThermalRequirementOutputDto | UpdateSunshineRequirementOutputDto | UpdateNutrientRequirementOutputDto): void;
  present(dto: LoadCropForEditDataDto | CreateCropStageOutputDto | UpdateCropStageOutputDto | DeleteCropStageOutputDto | UpdateTemperatureRequirementOutputDto | UpdateThermalRequirementOutputDto | UpdateSunshineRequirementOutputDto | UpdateNutrientRequirementOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');

    if ('crop' in dto) {
      const crop = (dto as LoadCropForEditDataDto).crop;
      this.view.control = {
        ...this.view.control,
        loading: false,
        error: null,
        pendingSuccessFlash: null,
        pendingErrorFlash: null,
        formData: {
          name: crop.name,
          crop_stages: crop.crop_stages ?? []
        }
      };
      return;
    }

    if ('stage' in dto && !('success' in dto)) {
      const existingStage = this.view.control.formData.crop_stages.find(s => s.id === dto.stage.id);
      if (existingStage) {
        this.presentUpdateCropStage(dto as UpdateCropStageOutputDto);
      } else {
        this.presentCreateCropStage(dto as CreateCropStageOutputDto);
      }
    } else if ('success' in dto && 'stageId' in dto) {
      this.presentDeleteCropStage(dto as DeleteCropStageOutputDto);
    } else if ('requirement' in dto) {
      const req = dto.requirement as any;
      if ('base_temperature' in req || 'optimal_min' in req || 'optimal_max' in req) {
        this.presentUpdateTemperatureRequirement(dto as UpdateTemperatureRequirementOutputDto);
      } else if ('required_gdd' in req) {
        this.presentUpdateThermalRequirement(dto as UpdateThermalRequirementOutputDto);
      } else if ('minimum_sunshine_hours' in req || 'target_sunshine_hours' in req) {
        this.presentUpdateSunshineRequirement(dto as UpdateSunshineRequirementOutputDto);
      } else if ('daily_uptake_n' in req || 'daily_uptake_p' in req || 'daily_uptake_k' in req) {
        this.presentUpdateNutrientRequirement(dto as UpdateNutrientRequirementOutputDto);
      }
    }
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      pendingSuccessFlash: null,
      pendingErrorFlash: pendingErrorFlashFromError(dto)
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

  presentUpdateCropStage(dto: UpdateCropStageOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const currentStages = this.view.control.formData.crop_stages;
    const updatedStages = currentStages.map(stage =>
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

  presentUpdateTemperatureRequirement(dto: UpdateTemperatureRequirementOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const updatedStages = this.view.control.formData.crop_stages.map(stage => {
      if (stage.id === dto.requirement.crop_stage_id) {
        return { ...stage, temperature_requirement: dto.requirement };
      }
      return stage;
    });
    this.view.control = {
      ...this.view.control,
      formData: { ...this.view.control.formData, crop_stages: updatedStages },
      pendingErrorFlash: null,
      pendingSuccessFlash: null
    };
  }

  presentUpdateThermalRequirement(dto: UpdateThermalRequirementOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const updatedStages = this.view.control.formData.crop_stages.map(stage => {
      if (stage.id === dto.requirement.crop_stage_id) {
        return { ...stage, thermal_requirement: dto.requirement };
      }
      return stage;
    });
    this.view.control = {
      ...this.view.control,
      formData: { ...this.view.control.formData, crop_stages: updatedStages },
      pendingErrorFlash: null,
      pendingSuccessFlash: null
    };
  }

  presentUpdateSunshineRequirement(dto: UpdateSunshineRequirementOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const updatedStages = this.view.control.formData.crop_stages.map(stage => {
      if (stage.id === dto.requirement.crop_stage_id) {
        return { ...stage, sunshine_requirement: dto.requirement };
      }
      return stage;
    });
    this.view.control = {
      ...this.view.control,
      formData: { ...this.view.control.formData, crop_stages: updatedStages },
      pendingErrorFlash: null,
      pendingSuccessFlash: null
    };
  }

  presentUpdateNutrientRequirement(dto: UpdateNutrientRequirementOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const updatedStages = this.view.control.formData.crop_stages.map(stage => {
      if (stage.id === dto.requirement.crop_stage_id) {
        return { ...stage, nutrient_requirement: dto.requirement };
      }
      return stage;
    });
    this.view.control = {
      ...this.view.control,
      formData: { ...this.view.control.formData, crop_stages: updatedStages },
      pendingErrorFlash: null,
      pendingSuccessFlash: null
    };
  }
}
