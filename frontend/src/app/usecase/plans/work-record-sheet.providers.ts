import { Provider } from '@angular/core';
import { AgriculturalTaskApiGateway } from '../../adapters/agricultural-tasks/agricultural-task-api.gateway';
import { WorkRecordApiGateway } from '../../adapters/plans/work-record-api.gateway';
import { WorkRecordSheetPresenter } from '../../adapters/plans/work-record-sheet.presenter';
import { AGRICULTURAL_TASK_GATEWAY } from '../agricultural-tasks/agricultural-task-gateway';
import { LOAD_AGRICULTURAL_TASK_LIST_OUTPUT_PORT } from '../agricultural-tasks/load-agricultural-task-list.output-port';
import { LoadAgriculturalTaskListUseCase } from '../agricultural-tasks/load-agricultural-task-list.usecase';
import { CREATE_WORK_RECORD_OUTPUT_PORT } from './create-work-record.output-port';
import { CreateWorkRecordUseCase } from './create-work-record.usecase';
import { DELETE_WORK_RECORD_OUTPUT_PORT } from './delete-work-record.output-port';
import { DeleteWorkRecordUseCase } from './delete-work-record.usecase';
import { UPDATE_WORK_RECORD_OUTPUT_PORT } from './update-work-record.output-port';
import { UpdateWorkRecordUseCase } from './update-work-record.usecase';
import { WORK_RECORD_GATEWAY } from './work-record-gateway';

export const WORK_RECORD_SHEET_PROVIDERS: readonly Provider[] = [
  WorkRecordSheetPresenter,
  CreateWorkRecordUseCase,
  UpdateWorkRecordUseCase,
  DeleteWorkRecordUseCase,
  LoadAgriculturalTaskListUseCase,
  { provide: CREATE_WORK_RECORD_OUTPUT_PORT, useExisting: WorkRecordSheetPresenter },
  { provide: UPDATE_WORK_RECORD_OUTPUT_PORT, useExisting: WorkRecordSheetPresenter },
  { provide: DELETE_WORK_RECORD_OUTPUT_PORT, useExisting: WorkRecordSheetPresenter },
  { provide: LOAD_AGRICULTURAL_TASK_LIST_OUTPUT_PORT, useExisting: WorkRecordSheetPresenter },
  { provide: WORK_RECORD_GATEWAY, useClass: WorkRecordApiGateway },
  { provide: AGRICULTURAL_TASK_GATEWAY, useClass: AgriculturalTaskApiGateway }
];
