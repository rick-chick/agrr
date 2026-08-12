import { Injectable } from '@angular/core';
import { WorkRecordSheetSavedEvent, WorkRecordSheetView } from '../../components/plans/work-record-sheet.view';
import { ErrorDto } from '../../domain/shared/error.dto';
import { buildWorkRecordSaveToast } from '../../domain/plans/work-record-save-toast';
import { mapWorkRecordSaveToastToPendingRequest } from './work-record-save-toast.presenter.helpers';
import { pendingUndoToastFromDeletion } from '../../core/view-effects/pending-undo-toast-presenter.helpers';
import { AgriculturalTaskListDataDto } from '../../usecase/agricultural-tasks/load-agricultural-task-list.dtos';
import { LoadAgriculturalTaskListOutputPort } from '../../usecase/agricultural-tasks/load-agricultural-task-list.output-port';
import { DeleteWorkRecordOutputPort } from '../../usecase/plans/delete-work-record.output-port';
import { DeleteWorkRecordSuccessDto } from '../../usecase/plans/delete-work-record.dtos';
import {
  SaveWorkRecordSheetSuccessDto,
  SaveWorkRecordSheetValidationErrorDto
} from '../../usecase/plans/save-work-record-sheet.dtos';
import { SaveWorkRecordSheetOutputPort } from '../../usecase/plans/save-work-record-sheet.output-port';
import { PreviewWorkRecordClimateStateDto } from '../../usecase/plans/preview-work-record-climate/preview-work-record-climate.dtos';
import { PreviewWorkRecordClimateOutputPort } from '../../usecase/plans/preview-work-record-climate/preview-work-record-climate.output-port';

@Injectable()
export class WorkRecordSheetPresenter
  implements
    DeleteWorkRecordOutputPort,
    LoadAgriculturalTaskListOutputPort,
    SaveWorkRecordSheetOutputPort,
    PreviewWorkRecordClimateOutputPort
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

  onSuccess(dto: SaveWorkRecordSheetSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const mode = dto.mode;
    this.view.control = {
      ...this.view.control,
      submitting: false,
      fieldErrors: {},
      error: null,
      photoError: null,
      pendingToast: mapWorkRecordSaveToastToPendingRequest(
        buildWorkRecordSaveToast(
          dto.workRecord,
          mode,
          this.view.control.saveToastContext
        )
      ),
      saveToastContext: null
    };
    this.view.close();
    this.onSavedCallback?.({ workRecord: dto.workRecord, mode });
  }

  onValidationError(dto: SaveWorkRecordSheetValidationErrorDto): void {
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

  presentClimatePreview(dto: PreviewWorkRecordClimateStateDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      climatePreview: {
        gddAtActual: dto.gddAtActual,
        weatherDate: dto.weatherDate,
        temperatureMax: dto.temperatureMax,
        temperatureMin: dto.temperatureMin,
        temperatureMean: dto.temperatureMean,
        loading: dto.loading
      }
    };
  }

  onDeleteSuccess(dto: DeleteWorkRecordSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      submitting: false,
      fieldErrors: {},
      error: null,
      pendingUndoToast: pendingUndoToastFromDeletion(dto.undo, () => this.onDeletedCallback?.())
    };
    this.view.close();
    this.onDeletedCallback?.();
  }
}
