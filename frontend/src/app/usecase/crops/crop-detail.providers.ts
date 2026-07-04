import { Provider } from '@angular/core';
import { AgriculturalTaskApiGateway } from '../../adapters/agricultural-tasks/agricultural-task-api.gateway';
import { CropApiGateway } from '../../adapters/crops/crop-api.gateway';
import { CropDetailPresenter } from '../../adapters/crops/crop-detail.presenter';
import { CropTaskScheduleBlueprintApiGateway } from '../../adapters/crops/crop-task-schedule-blueprint-api.gateway';
import { CropTaskTemplateApiGateway } from '../../adapters/crops/crop-task-template-api.gateway';
import {
  AGRICULTURAL_TASK_GATEWAY
} from '../agricultural-tasks/agricultural-task-gateway';
import { CROP_GATEWAY } from './crop-gateway';
import { CREATE_CROP_TASK_TEMPLATE_OUTPUT_PORT } from './crop-task-template.ports';
import { CreateCropTaskTemplateUseCase } from './create-crop-task-template.usecase';
import { CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY } from './crop-task-schedule-blueprint-gateway';
import { CreateCropTaskScheduleBlueprintUseCase } from './create-crop-task-schedule-blueprint.usecase';
import {
  CREATE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT,
  DELETE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT,
  LOAD_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT,
  REGENERATE_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT,
  UPDATE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT
} from './crop-task-schedule-blueprint.ports';
import { CROP_TASK_TEMPLATE_GATEWAY } from './crop-task-template-gateway';
import {
  DELETE_CROP_TASK_TEMPLATE_OUTPUT_PORT,
  LOAD_CROP_TASK_TEMPLATES_OUTPUT_PORT
} from './crop-task-template.ports';
import { DeleteCropTaskScheduleBlueprintUseCase } from './delete-crop-task-schedule-blueprint.usecase';
import { DeleteCropTaskTemplateUseCase } from './delete-crop-task-template.usecase';
import { DeleteCropUseCase } from './delete-crop.usecase';
import { DELETE_CROP_OUTPUT_PORT } from './delete-crop.output-port';
import { LoadAgriculturalTaskListUseCase } from '../agricultural-tasks/load-agricultural-task-list.usecase';
import { LOAD_AGRICULTURAL_TASK_LIST_OUTPUT_PORT } from '../agricultural-tasks/load-agricultural-task-list.output-port';
import { LoadCropDetailUseCase } from './load-crop-detail.usecase';
import { LOAD_CROP_DETAIL_OUTPUT_PORT } from './load-crop-detail.output-port';
import { LoadCropTaskScheduleBlueprintsUseCase } from './load-crop-task-schedule-blueprints.usecase';
import { LoadCropTaskTemplatesUseCase } from './load-crop-task-templates.usecase';
import { RegenerateCropTaskScheduleBlueprintsUseCase } from './regenerate-crop-task-schedule-blueprints.usecase';
import { UpdateCropTaskScheduleBlueprintUseCase } from './update-crop-task-schedule-blueprint.usecase';

/** Composition wiring for crop detail (adapters bound at usecase boundary). */
export const CROP_DETAIL_PROVIDERS: readonly Provider[] = [
  CropDetailPresenter,
  LoadCropDetailUseCase,
  DeleteCropUseCase,
  LoadCropTaskTemplatesUseCase,
  CreateCropTaskTemplateUseCase,
  DeleteCropTaskTemplateUseCase,
  LoadAgriculturalTaskListUseCase,
  LoadCropTaskScheduleBlueprintsUseCase,
  RegenerateCropTaskScheduleBlueprintsUseCase,
  UpdateCropTaskScheduleBlueprintUseCase,
  CreateCropTaskScheduleBlueprintUseCase,
  DeleteCropTaskScheduleBlueprintUseCase,
  { provide: LOAD_CROP_DETAIL_OUTPUT_PORT, useExisting: CropDetailPresenter },
  { provide: DELETE_CROP_OUTPUT_PORT, useExisting: CropDetailPresenter },
  { provide: LOAD_CROP_TASK_TEMPLATES_OUTPUT_PORT, useExisting: CropDetailPresenter },
  { provide: CREATE_CROP_TASK_TEMPLATE_OUTPUT_PORT, useExisting: CropDetailPresenter },
  { provide: DELETE_CROP_TASK_TEMPLATE_OUTPUT_PORT, useExisting: CropDetailPresenter },
  { provide: LOAD_AGRICULTURAL_TASK_LIST_OUTPUT_PORT, useExisting: CropDetailPresenter },
  { provide: LOAD_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT, useExisting: CropDetailPresenter },
  { provide: REGENERATE_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT, useExisting: CropDetailPresenter },
  { provide: UPDATE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT, useExisting: CropDetailPresenter },
  { provide: CREATE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT, useExisting: CropDetailPresenter },
  { provide: DELETE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT, useExisting: CropDetailPresenter },
  { provide: CROP_GATEWAY, useClass: CropApiGateway },
  { provide: CROP_TASK_TEMPLATE_GATEWAY, useClass: CropTaskTemplateApiGateway },
  { provide: CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY, useClass: CropTaskScheduleBlueprintApiGateway },
  { provide: AGRICULTURAL_TASK_GATEWAY, useClass: AgriculturalTaskApiGateway }
];

export { CropDetailPresenter } from '../../adapters/crops/crop-detail.presenter';
