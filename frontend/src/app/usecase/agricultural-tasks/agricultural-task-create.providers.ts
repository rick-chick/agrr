import { Provider } from '@angular/core';
import { AgriculturalTaskApiGateway } from '../../adapters/agricultural-tasks/agricultural-task-api.gateway';
import { AgriculturalTaskCreatePresenter } from '../../adapters/agricultural-tasks/agricultural-task-create.presenter';
import { AGRICULTURAL_TASK_GATEWAY } from './agricultural-task-gateway';
import { CreateAgriculturalTaskUseCase } from './create-agricultural-task.usecase';
import { CREATE_AGRICULTURAL_TASK_OUTPUT_PORT } from './create-agricultural-task.output-port';

/** Composition wiring for the agricultural task create feature (adapters bound at usecase boundary). */
export const AGRICULTURAL_TASK_CREATE_PROVIDERS: readonly Provider[] = [
  AgriculturalTaskCreatePresenter,
  CreateAgriculturalTaskUseCase,
  {
    provide: CREATE_AGRICULTURAL_TASK_OUTPUT_PORT,
    useExisting: AgriculturalTaskCreatePresenter
  },
  { provide: AGRICULTURAL_TASK_GATEWAY, useClass: AgriculturalTaskApiGateway }
];

export { AgriculturalTaskCreatePresenter } from '../../adapters/agricultural-tasks/agricultural-task-create.presenter';
