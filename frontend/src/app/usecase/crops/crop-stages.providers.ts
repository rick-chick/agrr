import { Provider } from '@angular/core';
import { CropApiGateway } from '../../adapters/crops/crop-api.gateway';
import { CropStagesPresenter } from '../../adapters/crops/crop-stages.presenter';
import { CropStageApiGateway } from '../../adapters/crops/crop-stage-api.gateway';
import { CreateCropStageUseCase } from './create-crop-stage.usecase';
import { CREATE_CROP_STAGE_OUTPUT_PORT } from './create-crop-stage.output-port';
import { CROP_GATEWAY } from './crop-gateway';
import { CROP_STAGE_GATEWAY } from './crop-stage-gateway';
import { DeleteCropStageUseCase } from './delete-crop-stage.usecase';
import { DELETE_CROP_STAGE_OUTPUT_PORT } from './delete-crop-stage.output-port';
import { LoadCropForEditUseCase } from './load-crop-for-edit.usecase';
import { LOAD_CROP_FOR_EDIT_OUTPUT_PORT } from './load-crop-for-edit.output-port';
import { UpdateCropStageUseCase } from './update-crop-stage.usecase';
import { UPDATE_CROP_STAGE_OUTPUT_PORT } from './update-crop-stage.output-port';
import { UpdateNutrientRequirementUseCase } from './update-nutrient-requirement.usecase';
import { UPDATE_NUTRIENT_REQUIREMENT_OUTPUT_PORT } from './update-nutrient-requirement.output-port';
import { UpdateSunshineRequirementUseCase } from './update-sunshine-requirement.usecase';
import { UPDATE_SUNSHINE_REQUIREMENT_OUTPUT_PORT } from './update-sunshine-requirement.output-port';
import { UpdateTemperatureRequirementUseCase } from './update-temperature-requirement.usecase';
import { UPDATE_TEMPERATURE_REQUIREMENT_OUTPUT_PORT } from './update-temperature-requirement.output-port';
import { UpdateThermalRequirementUseCase } from './update-thermal-requirement.usecase';
import { UPDATE_THERMAL_REQUIREMENT_OUTPUT_PORT } from './update-thermal-requirement.output-port';

export const CROP_STAGES_PROVIDERS: readonly Provider[] = [
  CropStagesPresenter,
  LoadCropForEditUseCase,
  CreateCropStageUseCase,
  UpdateCropStageUseCase,
  DeleteCropStageUseCase,
  UpdateTemperatureRequirementUseCase,
  UpdateThermalRequirementUseCase,
  UpdateSunshineRequirementUseCase,
  UpdateNutrientRequirementUseCase,
  { provide: LOAD_CROP_FOR_EDIT_OUTPUT_PORT, useExisting: CropStagesPresenter },
  { provide: CREATE_CROP_STAGE_OUTPUT_PORT, useExisting: CropStagesPresenter },
  { provide: UPDATE_CROP_STAGE_OUTPUT_PORT, useExisting: CropStagesPresenter },
  { provide: DELETE_CROP_STAGE_OUTPUT_PORT, useExisting: CropStagesPresenter },
  { provide: UPDATE_TEMPERATURE_REQUIREMENT_OUTPUT_PORT, useExisting: CropStagesPresenter },
  { provide: UPDATE_THERMAL_REQUIREMENT_OUTPUT_PORT, useExisting: CropStagesPresenter },
  { provide: UPDATE_SUNSHINE_REQUIREMENT_OUTPUT_PORT, useExisting: CropStagesPresenter },
  { provide: UPDATE_NUTRIENT_REQUIREMENT_OUTPUT_PORT, useExisting: CropStagesPresenter },
  { provide: CROP_GATEWAY, useClass: CropApiGateway },
  { provide: CROP_STAGE_GATEWAY, useClass: CropStageApiGateway }
];

export { CropStagesPresenter } from '../../adapters/crops/crop-stages.presenter';
