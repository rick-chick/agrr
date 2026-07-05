import { Provider } from '@angular/core';
import { AgriculturalTaskApiGateway } from '../../adapters/agricultural-tasks/agricultural-task-api.gateway';
import { CropApiGateway } from '../../adapters/crops/crop-api.gateway';
import { CropTaskScheduleBlueprintsPresenter } from '../../adapters/crops/crop-task-schedule-blueprints.presenter';
import { CropTaskScheduleBlueprintApiGateway } from '../../adapters/crops/crop-task-schedule-blueprint-api.gateway';
import { AGRICULTURAL_TASK_GATEWAY } from '../agricultural-tasks/agricultural-task-gateway';
import { CROP_GATEWAY } from './crop-gateway';
import { CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY } from './crop-task-schedule-blueprint-gateway';
import { CreateCropTaskScheduleBlueprintUseCase } from './create-crop-task-schedule-blueprint.usecase';
import {
  CREATE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT,
  DELETE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT,
  LOAD_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT,
  REGENERATE_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT,
  UPDATE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT
} from './crop-task-schedule-blueprint.ports';
import { DeleteCropTaskScheduleBlueprintUseCase } from './delete-crop-task-schedule-blueprint.usecase';
import { LoadAgriculturalTaskListUseCase } from '../agricultural-tasks/load-agricultural-task-list.usecase';
import { LOAD_AGRICULTURAL_TASK_LIST_OUTPUT_PORT } from '../agricultural-tasks/load-agricultural-task-list.output-port';
import { LoadCropDetailUseCase } from './load-crop-detail.usecase';
import { LOAD_CROP_DETAIL_OUTPUT_PORT } from './load-crop-detail.output-port';
import { LoadCropTaskScheduleBlueprintsUseCase } from './load-crop-task-schedule-blueprints.usecase';
import { RegenerateCropTaskScheduleBlueprintsUseCase } from './regenerate-crop-task-schedule-blueprints.usecase';
import { UpdateCropTaskScheduleBlueprintUseCase } from './update-crop-task-schedule-blueprint.usecase';

export const CROP_TASK_SCHEDULE_BLUEPRINTS_PROVIDERS: readonly Provider[] = [
  CropTaskScheduleBlueprintsPresenter,
  LoadCropDetailUseCase,
  LoadAgriculturalTaskListUseCase,
  LoadCropTaskScheduleBlueprintsUseCase,
  RegenerateCropTaskScheduleBlueprintsUseCase,
  UpdateCropTaskScheduleBlueprintUseCase,
  CreateCropTaskScheduleBlueprintUseCase,
  DeleteCropTaskScheduleBlueprintUseCase,
  { provide: LOAD_CROP_DETAIL_OUTPUT_PORT, useExisting: CropTaskScheduleBlueprintsPresenter },
  { provide: LOAD_AGRICULTURAL_TASK_LIST_OUTPUT_PORT, useExisting: CropTaskScheduleBlueprintsPresenter },
  { provide: LOAD_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT, useExisting: CropTaskScheduleBlueprintsPresenter },
  { provide: REGENERATE_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT, useExisting: CropTaskScheduleBlueprintsPresenter },
  { provide: UPDATE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT, useExisting: CropTaskScheduleBlueprintsPresenter },
  { provide: CREATE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT, useExisting: CropTaskScheduleBlueprintsPresenter },
  { provide: DELETE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT, useExisting: CropTaskScheduleBlueprintsPresenter },
  { provide: CROP_GATEWAY, useClass: CropApiGateway },
  { provide: CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY, useClass: CropTaskScheduleBlueprintApiGateway },
  { provide: AGRICULTURAL_TASK_GATEWAY, useClass: AgriculturalTaskApiGateway }
];

export { CropTaskScheduleBlueprintsPresenter } from '../../adapters/crops/crop-task-schedule-blueprints.presenter';
