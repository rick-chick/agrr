import { Injectable } from '@angular/core';
import { WorkRecordSheetSavedEvent, WorkRecordSheetView } from '../../components/plans/work-record-sheet.view';
import { ErrorDto } from '../../domain/shared/error.dto';
import { AgriculturalTaskListDataDto } from '../../usecase/agricultural-tasks/load-agricultural-task-list.dtos';
import { LoadAgriculturalTaskListOutputPort } from '../../usecase/agricultural-tasks/load-agricultural-task-list.output-port';
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
  implements
    CreateWorkRecordOutputPort,
    UpdateWorkRecordOutputPort,
    DeleteWorkRecordOutputPort,
    LoadAgriculturalTaskListOutputPort
{
  private view: WorkRecordSheetView | null = null;
  onSavedCallback: ((event: WorkRecordSheetSavedEvent) => void) | null = null;
  onDeletedCallback: (() => void) | null = null;

  setView(view: WorkRecordSheetView): void {
    this.view = view;
  }

  present(dto: AgriculturalTaskListDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loadingTaskChips: false,
      taskChips: dto.tasks.map((task) => ({
        id: task.id,
        name: task.name,
        task_type: task.task_type ?? null
      }))
    };
  }

  onSuccess(dto: CreateWorkRecordSuccessDto | UpdateWorkRecordSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const mode = this.view.control.mode;
    this.view.control = {
      ...this.view.control,
      submitting: false,
      fieldErrors: {},
      error: null,
      pendingToastKey: savedToastKey(mode)
    };
    this.view.close();
    this.onSavedCallback?.({ workRecord: dto.workRecord, mode });
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
    if (this.view.control.loadingTaskChips) {
      this.view.control = {
        ...this.view.control,
        loadingTaskChips: false
      };
      return;
    }
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
      error: null,
      pendingToastKey: 'plans.work_records.toast.record_deleted'
    };
    this.view.close();
    this.onDeletedCallback?.();
  }
}

function savedToastKey(mode: WorkRecordSheetSavedEvent['mode']): string {
  if (mode === 'edit') {
    return 'plans.work_records.toast.record_updated';
  }
  if (mode === 'create-adhoc') {
    return 'plans.work.toast.record_saved_adhoc';
  }
  return 'plans.work.toast.record_saved';
}
