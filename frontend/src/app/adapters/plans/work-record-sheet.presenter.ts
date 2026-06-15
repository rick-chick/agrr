import { Injectable } from '@angular/core';
import { WorkRecordSheetView } from '../../components/plans/work-record-sheet.view';
import { ErrorDto } from '../../domain/shared/error.dto';
import { CreateWorkRecordOutputPort } from '../../usecase/plans/create-work-record.output-port';
import {
  CreateWorkRecordSuccessDto,
  CreateWorkRecordValidationErrorDto
} from '../../usecase/plans/create-work-record.dtos';
import { UpdateWorkRecordOutputPort } from '../../usecase/plans/update-work-record.output-port';
import {
  UpdateWorkRecordSuccessDto,
  UpdateWorkRecordValidationErrorDto
} from '../../usecase/plans/update-work-record.dtos';
import { DeleteWorkRecordOutputPort } from '../../usecase/plans/delete-work-record.output-port';

@Injectable()
export class WorkRecordSheetPresenter
  implements CreateWorkRecordOutputPort, UpdateWorkRecordOutputPort, DeleteWorkRecordOutputPort
{
  private view: WorkRecordSheetView | null = null;
  onSavedCallback: (() => void) | null = null;
  onDeletedCallback: (() => void) | null = null;

  setView(view: WorkRecordSheetView): void {
    this.view = view;
  }

  onSuccess(_dto: CreateWorkRecordSuccessDto | UpdateWorkRecordSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      submitting: false,
      fieldErrors: {},
      error: null
    };
    this.view.close();
    this.onSavedCallback?.();
  }

  onValidationError(dto: CreateWorkRecordValidationErrorDto | UpdateWorkRecordValidationErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      submitting: false,
      fieldErrors: dto.fieldErrors,
      error: null
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      submitting: false,
      fieldErrors: {},
      error: dto.message
    };
  }

  onDeleteSuccess(): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      submitting: false,
      fieldErrors: {},
      error: null
    };
    this.view.close();
    this.onDeletedCallback?.();
  }
}
