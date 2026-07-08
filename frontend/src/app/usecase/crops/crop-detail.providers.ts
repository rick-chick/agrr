import { Provider } from '@angular/core';
import { CropApiGateway } from '../../adapters/crops/crop-api.gateway';
import { CropDetailPresenter } from '../../adapters/crops/crop-detail.presenter';
import { CropTaskScheduleBlueprintApiGateway } from '../../adapters/crops/crop-task-schedule-blueprint-api.gateway';
import { CROP_GATEWAY } from './crop-gateway';
import { CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY } from './crop-task-schedule-blueprint-gateway';
import { DeleteCropUseCase } from './delete-crop.usecase';
import { DELETE_CROP_OUTPUT_PORT } from './delete-crop.output-port';
import { LoadCropDetailUseCase } from './load-crop-detail.usecase';
import { LOAD_CROP_DETAIL_OUTPUT_PORT } from './load-crop-detail.output-port';
import { LoadCropTaskScheduleBlueprintsUseCase } from './load-crop-task-schedule-blueprints.usecase';
import { LOAD_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT } from './crop-task-schedule-blueprint.ports';

/** Composition wiring for crop detail (adapters bound at usecase boundary). */
export const CROP_DETAIL_PROVIDERS: readonly Provider[] = [
  CropDetailPresenter,
  LoadCropDetailUseCase,
  DeleteCropUseCase,
  LoadCropTaskScheduleBlueprintsUseCase,
  { provide: LOAD_CROP_DETAIL_OUTPUT_PORT, useExisting: CropDetailPresenter },
  { provide: DELETE_CROP_OUTPUT_PORT, useExisting: CropDetailPresenter },
  { provide: LOAD_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT, useExisting: CropDetailPresenter },
  { provide: CROP_GATEWAY, useClass: CropApiGateway },
  { provide: CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY, useClass: CropTaskScheduleBlueprintApiGateway }
];

export { CropDetailPresenter } from '../../adapters/crops/crop-detail.presenter';
