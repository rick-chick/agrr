import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import {
  SaveWorkRecordSheetSuccessDto,
  SaveWorkRecordSheetValidationErrorDto
} from './save-work-record-sheet.dtos';

export interface SaveWorkRecordSheetOutputPort {
  onSuccess(dto: SaveWorkRecordSheetSuccessDto): void;
  onValidationError(dto: SaveWorkRecordSheetValidationErrorDto): void;
  onError(dto: ErrorDto): void;
}

export const SAVE_WORK_RECORD_SHEET_OUTPUT_PORT = new InjectionToken<SaveWorkRecordSheetOutputPort>(
  'SAVE_WORK_RECORD_SHEET_OUTPUT_PORT'
);
