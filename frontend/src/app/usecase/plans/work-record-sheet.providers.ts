import { Provider } from '@angular/core';
import { WorkRecordApiGateway } from '../../adapters/plans/work-record-api.gateway';
import { WorkRecordSheetPresenter } from '../../adapters/plans/work-record-sheet.presenter';
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
  { provide: CREATE_WORK_RECORD_OUTPUT_PORT, useExisting: WorkRecordSheetPresenter },
  { provide: UPDATE_WORK_RECORD_OUTPUT_PORT, useExisting: WorkRecordSheetPresenter },
  { provide: DELETE_WORK_RECORD_OUTPUT_PORT, useExisting: WorkRecordSheetPresenter },
  { provide: WORK_RECORD_GATEWAY, useClass: WorkRecordApiGateway }
];
