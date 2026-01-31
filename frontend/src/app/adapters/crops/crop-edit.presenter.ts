import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { CropEditView } from '../../components/masters/crops/crop-edit.view';
import { LoadCropForEditOutputPort } from '../../usecase/crops/load-crop-for-edit.output-port';
import { LoadCropForEditDataDto } from '../../usecase/crops/load-crop-for-edit.dtos';
import { UpdateCropOutputPort } from '../../usecase/crops/update-crop.output-port';
import { UpdateCropSuccessDto } from '../../usecase/crops/update-crop.dtos';
import { FlashMessageService } from '../../services/flash-message.service';
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

@Injectable()
export class CropEditPresenter implements
  LoadCropForEditOutputPort,
  UpdateCropOutputPort,
  CreateCropStageOutputPort,
  UpdateCropStageOutputPort,
  DeleteCropStageOutputPort,
  UpdateTemperatureRequirementOutputPort,
  UpdateThermalRequirementOutputPort,
  UpdateSunshineRequirementOutputPort,
  UpdateNutrientRequirementOutputPort {
  private readonly flashMessage = inject(FlashMessageService);
  private view: CropEditView | null = null;

  setView(view: CropEditView): void {
    this.view = view;
  }

  // Function overloads for present method
  present(dto: LoadCropForEditDataDto): void;
  present(dto: CreateCropStageOutputDto | UpdateCropStageOutputDto | DeleteCropStageOutputDto | UpdateTemperatureRequirementOutputDto | UpdateThermalRequirementOutputDto | UpdateSunshineRequirementOutputDto | UpdateNutrientRequirementOutputDto): void;
  present(dto: LoadCropForEditDataDto | CreateCropStageOutputDto | UpdateCropStageOutputDto | DeleteCropStageOutputDto | UpdateTemperatureRequirementOutputDto | UpdateThermalRequirementOutputDto | UpdateSunshineRequirementOutputDto | UpdateNutrientRequirementOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    
    // LoadCropForEditDataDto has 'crop' property
    if ('crop' in dto) {
      const crop = (dto as LoadCropForEditDataDto).crop;
      this.view.control = {
        ...this.view.control,
        loading: false,
        error: null,
        formData: {
          name: crop.name,
          variety: crop.variety ?? null,
          area_per_unit: crop.area_per_unit ?? null,
          revenue_per_area: crop.revenue_per_area ?? null,
          region: crop.region ?? null,
          groups: crop.groups ?? [],
          groupsDisplay: (crop.groups ?? []).join(', '),
          is_reference: crop.is_reference ?? false,
          crop_stages: crop.crop_stages ?? []
        }
      };
      return;
    }
    
    // Type guards for other DTOs
    if ('stage' in dto && !('success' in dto)) {
      // CreateCropStageOutputDto or UpdateCropStageOutputDto
      const existingStage = this.view.control.formData.crop_stages.find(s => s.id === dto.stage.id);
      if (existingStage) {
        this.presentUpdateCropStage(dto as UpdateCropStageOutputDto);
      } else {
        this.presentCreateCropStage(dto as CreateCropStageOutputDto);
      }
    } else if ('success' in dto && 'stageId' in dto) {
      // DeleteCropStageOutputDto
      this.presentDeleteCropStage(dto as DeleteCropStageOutputDto);
    } else if ('requirement' in dto) {
      // Requirement DTOs - check requirement type by properties
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
    this.flashMessage.show({ type: 'error', text: dto.message });
    this.view.control = {
      ...this.view.control,
      loading: false,
      saving: false,
      error: null
    };
  }

  onSuccess(_dto: UpdateCropSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.flashMessage.show({ type: 'success', text: 'Crop updated successfully' });
    this.view.control = {
      ...this.view.control,
      saving: false
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
      }
    };
    this.flashMessage.show({ type: 'success', text: 'Crop stage created successfully' });
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
      }
    };
    this.flashMessage.show({ type: 'success', text: 'Crop stage updated successfully' });
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
      }
    };
    this.flashMessage.show({ type: 'success', text: 'Crop stage deleted successfully' });
  }

  presentUpdateTemperatureRequirement(dto: UpdateTemperatureRequirementOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const currentStages = this.view.control.formData.crop_stages;
    const updatedStages = currentStages.map(stage => {
      if (stage.id === dto.requirement.crop_stage_id) {
        return {
          ...stage,
          temperature_requirement: dto.requirement
        };
      }
      return stage;
    });
    this.view.control = {
      ...this.view.control,
      formData: {
        ...this.view.control.formData,
        crop_stages: updatedStages
      }
    };
    this.flashMessage.show({ type: 'success', text: 'Temperature requirement updated successfully' });
  }

  presentUpdateThermalRequirement(dto: UpdateThermalRequirementOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const currentStages = this.view.control.formData.crop_stages;
    const updatedStages = currentStages.map(stage => {
      if (stage.id === dto.requirement.crop_stage_id) {
        return {
          ...stage,
          thermal_requirement: dto.requirement
        };
      }
      return stage;
    });
    this.view.control = {
      ...this.view.control,
      formData: {
        ...this.view.control.formData,
        crop_stages: updatedStages
      }
    };
    this.flashMessage.show({ type: 'success', text: 'Thermal requirement updated successfully' });
  }

  presentUpdateSunshineRequirement(dto: UpdateSunshineRequirementOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const currentStages = this.view.control.formData.crop_stages;
    const updatedStages = currentStages.map(stage => {
      if (stage.id === dto.requirement.crop_stage_id) {
        return {
          ...stage,
          sunshine_requirement: dto.requirement
        };
      }
      return stage;
    });
    this.view.control = {
      ...this.view.control,
      formData: {
        ...this.view.control.formData,
        crop_stages: updatedStages
      }
    };
    this.flashMessage.show({ type: 'success', text: 'Sunshine requirement updated successfully' });
  }

  presentUpdateNutrientRequirement(dto: UpdateNutrientRequirementOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const currentStages = this.view.control.formData.crop_stages;
    const updatedStages = currentStages.map(stage => {
      if (stage.id === dto.requirement.crop_stage_id) {
        return {
          ...stage,
          nutrient_requirement: dto.requirement
        };
      }
      return stage;
    });
    this.view.control = {
      ...this.view.control,
      formData: {
        ...this.view.control.formData,
        crop_stages: updatedStages
      }
    };
    this.flashMessage.show({ type: 'success', text: 'Nutrient requirement updated successfully' });
  }
}
