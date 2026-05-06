import { Provider } from '@angular/core';
import { AgriculturalTaskApiGateway } from '../../adapters/agricultural-tasks/agricultural-task-api.gateway';
import { AgriculturalTaskEditPresenter } from '../../adapters/agricultural-tasks/agricultural-task-edit.presenter';
import { AGRICULTURAL_TASK_GATEWAY } from './agricultural-task-gateway';
import { LoadAgriculturalTaskForEditUseCase } from './load-agricultural-task-for-edit.usecase';
import { UpdateAgriculturalTaskUseCase } from './update-agricultural-task.usecase';
import { LOAD_AGRICULTURAL_TASK_FOR_EDIT_OUTPUT_PORT } from './load-agricultural-task-for-edit.output-port';
import { UPDATE_AGRICULTURAL_TASK_OUTPUT_PORT } from './update-agricultural-task.output-port';

/** Composition wiring for the agricultural task edit feature (adapters bound at usecase boundary). */
export const AGRICULTURAL_TASK_EDIT_PROVIDERS: readonly Provider[] = [
  AgriculturalTaskEditPresenter,
  LoadAgriculturalTaskForEditUseCase,
  UpdateAgriculturalTaskUseCase,
  {
    provide: LOAD_AGRICULTURAL_TASK_FOR_EDIT_OUTPUT_PORT,
    useExisting: AgriculturalTaskEditPresenter
  },
  {
    provide: UPDATE_AGRICULTURAL_TASK_OUTPUT_PORT,
    useExisting: AgriculturalTaskEditPresenter
  },
  { provide: AGRICULTURAL_TASK_GATEWAY, useClass: AgriculturalTaskApiGateway }
];

export { AgriculturalTaskEditPresenter } from '../../adapters/agricultural-tasks/agricultural-task-edit.presenter';
