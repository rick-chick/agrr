import { Provider } from '@angular/core';
import { CropApiGateway } from '../../adapters/crops/crop-api.gateway';
import { CropStageEditPresenter } from '../../adapters/crops/crop-stage-edit.presenter';
import { CropStageApiGateway } from '../../adapters/crops/crop-stage-api.gateway';
import { CropTaskScheduleBlueprintApiGateway } from '../../adapters/crops/crop-task-schedule-blueprint-api.gateway';
import { CROP_GATEWAY } from './crop-gateway';
import { CROP_STAGE_GATEWAY } from './crop-stage-gateway';
import { CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY } from './crop-task-schedule-blueprint-gateway';
import { DeleteCropStageUseCase } from './delete-crop-stage.usecase';
import { DELETE_CROP_STAGE_OUTPUT_PORT } from './delete-crop-stage.output-port';
import { LoadCropForEditUseCase } from './load-crop-for-edit.usecase';
import { LOAD_CROP_FOR_EDIT_OUTPUT_PORT } from './load-crop-for-edit.output-port';
import { LoadCropTaskScheduleBlueprintsUseCase } from './load-crop-task-schedule-blueprints.usecase';
import { LOAD_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT } from './crop-task-schedule-blueprint.ports';
import { SaveCropStagePanelUseCase } from './save-crop-stage-panel.usecase';
import { SAVE_CROP_STAGE_PANEL_OUTPUT_PORT } from './save-crop-stage-panel.output-port';
import { SaveCropStageAdvancedDetailsUseCase } from './save-crop-stage-advanced-details.usecase';
import { SAVE_CROP_STAGE_ADVANCED_DETAILS_OUTPUT_PORT } from './save-crop-stage-advanced-details.output-port';

export const CROP_STAGE_EDIT_PROVIDERS: readonly Provider[] = [
  CropStageEditPresenter,
  LoadCropForEditUseCase,
  LoadCropTaskScheduleBlueprintsUseCase,
  DeleteCropStageUseCase,
  SaveCropStagePanelUseCase,
  SaveCropStageAdvancedDetailsUseCase,
  { provide: LOAD_CROP_FOR_EDIT_OUTPUT_PORT, useExisting: CropStageEditPresenter },
  { provide: LOAD_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT, useExisting: CropStageEditPresenter },
  { provide: DELETE_CROP_STAGE_OUTPUT_PORT, useExisting: CropStageEditPresenter },
  { provide: SAVE_CROP_STAGE_PANEL_OUTPUT_PORT, useExisting: CropStageEditPresenter },
  { provide: SAVE_CROP_STAGE_ADVANCED_DETAILS_OUTPUT_PORT, useExisting: CropStageEditPresenter },
  { provide: CROP_GATEWAY, useClass: CropApiGateway },
  { provide: CROP_STAGE_GATEWAY, useClass: CropStageApiGateway },
  { provide: CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY, useClass: CropTaskScheduleBlueprintApiGateway }
];

export { CropStageEditPresenter } from '../../adapters/crops/crop-stage-edit.presenter';
