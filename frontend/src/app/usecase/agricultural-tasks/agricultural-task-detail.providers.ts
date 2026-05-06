import { Provider } from '@angular/core';
import { AgriculturalTaskApiGateway } from '../../adapters/agricultural-tasks/agricultural-task-api.gateway';
import { AgriculturalTaskDetailPresenter } from '../../adapters/agricultural-tasks/agricultural-task-detail.presenter';
import { AGRICULTURAL_TASK_GATEWAY } from './agricultural-task-gateway';
import { DeleteAgriculturalTaskUseCase } from './delete-agricultural-task.usecase';
import { DELETE_AGRICULTURAL_TASK_OUTPUT_PORT } from './delete-agricultural-task.output-port';
import { LOAD_AGRICULTURAL_TASK_DETAIL_OUTPUT_PORT } from './load-agricultural-task-detail.output-port';
import { LoadAgriculturalTaskDetailUseCase } from './load-agricultural-task-detail.usecase';

/** Composition wiring for the agricultural task detail feature (adapters bound at usecase boundary). */
export const AGRICULTURAL_TASK_DETAIL_PROVIDERS: readonly Provider[] = [
  AgriculturalTaskDetailPresenter,
  LoadAgriculturalTaskDetailUseCase,
  DeleteAgriculturalTaskUseCase,
  {
    provide: LOAD_AGRICULTURAL_TASK_DETAIL_OUTPUT_PORT,
    useExisting: AgriculturalTaskDetailPresenter
  },
  {
    provide: DELETE_AGRICULTURAL_TASK_OUTPUT_PORT,
    useExisting: AgriculturalTaskDetailPresenter
  },
  { provide: AGRICULTURAL_TASK_GATEWAY, useClass: AgriculturalTaskApiGateway }
];

export { AgriculturalTaskDetailPresenter } from '../../adapters/agricultural-tasks/agricultural-task-detail.presenter';
