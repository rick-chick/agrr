import { Provider } from '@angular/core';
import { CropApiGateway } from '../../adapters/crops/crop-api.gateway';
import { CropStagesPresenter } from '../../adapters/crops/crop-stages.presenter';
import { CropStageApiGateway } from '../../adapters/crops/crop-stage-api.gateway';
import { CropTaskScheduleBlueprintApiGateway } from '../../adapters/crops/crop-task-schedule-blueprint-api.gateway';
import { CreateCropStageUseCase } from './create-crop-stage.usecase';
import { CREATE_CROP_STAGE_OUTPUT_PORT } from './create-crop-stage.output-port';
import { CROP_GATEWAY } from './crop-gateway';
import { CROP_STAGE_GATEWAY } from './crop-stage-gateway';
import { CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY } from './crop-task-schedule-blueprint-gateway';
import { LoadCropForEditUseCase } from './load-crop-for-edit.usecase';
import { LOAD_CROP_FOR_EDIT_OUTPUT_PORT } from './load-crop-for-edit.output-port';
import { LoadCropTaskScheduleBlueprintsUseCase } from './load-crop-task-schedule-blueprints.usecase';
import { LOAD_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT } from './crop-task-schedule-blueprint.ports';
import { ReorderCropStagesUseCase } from './reorder-crop-stages.usecase';
import { REORDER_CROP_STAGES_OUTPUT_PORT } from './reorder-crop-stages.output-port';

export const CROP_STAGES_PROVIDERS: readonly Provider[] = [
  CropStagesPresenter,
  LoadCropForEditUseCase,
  LoadCropTaskScheduleBlueprintsUseCase,
  CreateCropStageUseCase,
  ReorderCropStagesUseCase,
  { provide: LOAD_CROP_FOR_EDIT_OUTPUT_PORT, useExisting: CropStagesPresenter },
  { provide: LOAD_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT, useExisting: CropStagesPresenter },
  { provide: CREATE_CROP_STAGE_OUTPUT_PORT, useExisting: CropStagesPresenter },
  { provide: REORDER_CROP_STAGES_OUTPUT_PORT, useExisting: CropStagesPresenter },
  { provide: CROP_GATEWAY, useClass: CropApiGateway },
  { provide: CROP_STAGE_GATEWAY, useClass: CropStageApiGateway },
  { provide: CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY, useClass: CropTaskScheduleBlueprintApiGateway }
];

export { CropStagesPresenter } from '../../adapters/crops/crop-stages.presenter';
