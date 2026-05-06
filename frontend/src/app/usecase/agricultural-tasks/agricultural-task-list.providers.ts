import { Provider } from '@angular/core';
import { AgriculturalTaskApiGateway } from '../../adapters/agricultural-tasks/agricultural-task-api.gateway';
import { AgriculturalTaskListPresenter } from '../../adapters/agricultural-tasks/agricultural-task-list.presenter';
import { AGRICULTURAL_TASK_GATEWAY } from './agricultural-task-gateway';
import { DeleteAgriculturalTaskUseCase } from './delete-agricultural-task.usecase';
import { DELETE_AGRICULTURAL_TASK_OUTPUT_PORT } from './delete-agricultural-task.output-port';
import { LOAD_AGRICULTURAL_TASK_LIST_OUTPUT_PORT } from './load-agricultural-task-list.output-port';
import { LoadAgriculturalTaskListUseCase } from './load-agricultural-task-list.usecase';

/** Composition wiring for the agricultural task list feature (adapters bound at usecase boundary). */
export const AGRICULTURAL_TASK_LIST_PROVIDERS: readonly Provider[] = [
  AgriculturalTaskListPresenter,
  LoadAgriculturalTaskListUseCase,
  DeleteAgriculturalTaskUseCase,
  {
    provide: LOAD_AGRICULTURAL_TASK_LIST_OUTPUT_PORT,
    useExisting: AgriculturalTaskListPresenter
  },
  {
    provide: DELETE_AGRICULTURAL_TASK_OUTPUT_PORT,
    useExisting: AgriculturalTaskListPresenter
  },
  { provide: AGRICULTURAL_TASK_GATEWAY, useClass: AgriculturalTaskApiGateway }
];

export { AgriculturalTaskListPresenter } from '../../adapters/agricultural-tasks/agricultural-task-list.presenter';
