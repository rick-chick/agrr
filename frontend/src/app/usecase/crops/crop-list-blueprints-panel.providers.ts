import { Provider } from '@angular/core';
import { CropApiGateway } from '../../adapters/crops/crop-api.gateway';
import { CropTaskScheduleBlueprintApiGateway } from '../../adapters/crops/crop-task-schedule-blueprint-api.gateway';
import { CropListBlueprintsPanelPresenter } from '../../adapters/crops/crop-list-blueprints-panel.presenter';
import { CROP_GATEWAY } from './crop-gateway';
import { CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY } from './crop-task-schedule-blueprint-gateway';
import { LoadCropForEditUseCase } from './load-crop-for-edit.usecase';
import { LOAD_CROP_FOR_EDIT_OUTPUT_PORT } from './load-crop-for-edit.output-port';
import { LoadCropTaskScheduleBlueprintsUseCase } from './load-crop-task-schedule-blueprints.usecase';
import { LOAD_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT } from './crop-task-schedule-blueprint.ports';

export const CROP_LIST_BLUEPRINTS_PANEL_PROVIDERS: readonly Provider[] = [
  CropListBlueprintsPanelPresenter,
  LoadCropForEditUseCase,
  LoadCropTaskScheduleBlueprintsUseCase,
  { provide: LOAD_CROP_FOR_EDIT_OUTPUT_PORT, useExisting: CropListBlueprintsPanelPresenter },
  {
    provide: LOAD_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT,
    useExisting: CropListBlueprintsPanelPresenter
  },
  { provide: CROP_GATEWAY, useClass: CropApiGateway },
  { provide: CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY, useClass: CropTaskScheduleBlueprintApiGateway }
];

export { CropListBlueprintsPanelPresenter } from '../../adapters/crops/crop-list-blueprints-panel.presenter';
