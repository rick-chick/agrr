import { Provider } from '@angular/core';
import { AgriculturalTaskApiGateway } from '../../adapters/agricultural-tasks/agricultural-task-api.gateway';
import { FertilizeApiGateway } from '../../adapters/fertilizes/fertilize-api.gateway';
import { PesticideApiGateway } from '../../adapters/pesticides/pesticide-api.gateway';
import { WorkRecordPhotoApiGateway } from '../../adapters/plans/work-record-photo-api.gateway';
import { WorkRecordApiGateway } from '../../adapters/plans/work-record-api.gateway';
import { WorkRecordSheetPresenter } from '../../adapters/plans/work-record-sheet.presenter';
import { AGRICULTURAL_TASK_GATEWAY } from '../agricultural-tasks/agricultural-task-gateway';
import { LOAD_AGRICULTURAL_TASK_LIST_OUTPUT_PORT } from '../agricultural-tasks/load-agricultural-task-list.output-port';
import { LoadAgriculturalTaskListUseCase } from '../agricultural-tasks/load-agricultural-task-list.usecase';
import { FERTILIZE_GATEWAY } from '../fertilizes/fertilize-gateway';
import { LOAD_FERTILIZE_LIST_OUTPUT_PORT } from '../fertilizes/load-fertilize-list.output-port';
import { LoadFertilizeListUseCase } from '../fertilizes/load-fertilize-list.usecase';
import { PESTICIDE_GATEWAY } from '../pesticides/pesticide-gateway';
import { LOAD_CROP_PESTICIDE_LIST_OUTPUT_PORT } from '../pesticides/load-crop-pesticide-list.output-port';
import { LoadCropPesticideListUseCase } from '../pesticides/load-crop-pesticide-list.usecase';
import { DELETE_WORK_RECORD_OUTPUT_PORT } from './delete-work-record.output-port';
import { DeleteWorkRecordUseCase } from './delete-work-record.usecase';
import { SAVE_WORK_RECORD_SHEET_OUTPUT_PORT } from './save-work-record-sheet.output-port';
import { SaveWorkRecordSheetUseCase } from './save-work-record-sheet.usecase';
import { WORK_RECORD_PHOTO_GATEWAY } from './work-record-photo-gateway';
import { WORK_RECORD_GATEWAY } from './work-record-gateway';
import { FieldClimateApiGateway } from '../../adapters/plans/field-climate-api.gateway';
import { FIELD_CLIMATE_GATEWAY } from './field-climate/field-climate.gateway';
import { PreviewWorkRecordClimateUseCase } from './preview-work-record-climate/preview-work-record-climate.usecase';
import { PREVIEW_WORK_RECORD_CLIMATE_OUTPUT_PORT } from './preview-work-record-climate/preview-work-record-climate.output-port';

export const WORK_RECORD_SHEET_PROVIDERS: readonly Provider[] = [
  WorkRecordSheetPresenter,
  DeleteWorkRecordUseCase,
  SaveWorkRecordSheetUseCase,
  LoadAgriculturalTaskListUseCase,
  LoadFertilizeListUseCase,
  LoadCropPesticideListUseCase,
  PreviewWorkRecordClimateUseCase,
  { provide: DELETE_WORK_RECORD_OUTPUT_PORT, useExisting: WorkRecordSheetPresenter },
  { provide: SAVE_WORK_RECORD_SHEET_OUTPUT_PORT, useExisting: WorkRecordSheetPresenter },
  { provide: LOAD_AGRICULTURAL_TASK_LIST_OUTPUT_PORT, useExisting: WorkRecordSheetPresenter },
  { provide: LOAD_FERTILIZE_LIST_OUTPUT_PORT, useExisting: WorkRecordSheetPresenter },
  { provide: LOAD_CROP_PESTICIDE_LIST_OUTPUT_PORT, useExisting: WorkRecordSheetPresenter },
  { provide: PREVIEW_WORK_RECORD_CLIMATE_OUTPUT_PORT, useExisting: WorkRecordSheetPresenter },
  { provide: WORK_RECORD_GATEWAY, useClass: WorkRecordApiGateway },
  { provide: WORK_RECORD_PHOTO_GATEWAY, useClass: WorkRecordPhotoApiGateway },
  { provide: AGRICULTURAL_TASK_GATEWAY, useClass: AgriculturalTaskApiGateway },
  { provide: FERTILIZE_GATEWAY, useClass: FertilizeApiGateway },
  { provide: PESTICIDE_GATEWAY, useClass: PesticideApiGateway },
  { provide: FIELD_CLIMATE_GATEWAY, useClass: FieldClimateApiGateway }
];
