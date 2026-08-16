import { Injectable } from '@angular/core';
import { WorkRecordSheetSavedEvent, WorkRecordSheetView } from '../../components/plans/work-record-sheet.view';
import { ErrorDto } from '../../domain/shared/error.dto';
import { buildWorkRecordSaveToast } from '../../domain/plans/work-record-save-toast';
import { mapWorkRecordSaveToastToPendingRequest } from './work-record-save-toast.presenter.helpers';
import { pendingUndoToastFromDeletion } from '../../core/view-effects/pending-undo-toast-presenter.helpers';
import { AgriculturalTaskListDataDto } from '../../usecase/agricultural-tasks/load-agricultural-task-list.dtos';
import { LoadAgriculturalTaskListOutputPort } from '../../usecase/agricultural-tasks/load-agricultural-task-list.output-port';
import { FertilizeListDataDto } from '../../usecase/fertilizes/load-fertilize-list.dtos';
import { LoadFertilizeListOutputPort } from '../../usecase/fertilizes/load-fertilize-list.output-port';
import { CropPesticideListDataDto } from '../../usecase/pesticides/load-crop-pesticide-list.dtos';
import { LoadCropPesticideListOutputPort } from '../../usecase/pesticides/load-crop-pesticide-list.output-port';
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
    LoadFertilizeListOutputPort,
    LoadCropPesticideListOutputPort,
    SaveWorkRecordSheetOutputPort,
    PreviewWorkRecordClimateOutputPort
{
  private view: WorkRecordSheetView | null = null;
  onSavedCallback: ((event: WorkRecordSheetSavedEvent) => void) | null = null;
  onDeletedCallback: (() => void) | null = null;

  setView(view: WorkRecordSheetView): void {
    this.view = view;
  }

  present(dto: AgriculturalTaskListDataDto | FertilizeListDataDto | CropPesticideListDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if ('tasks' in dto) {
      this.view.control = {
        ...this.view.control,
        loadingTaskChips: false,
        taskChips: dto.tasks.map((task) => ({
          id: task.id,
          name: task.name,
          task_type: task.task_type ?? null
        }))
      };
      return;
    }
    if ('fertilizes' in dto) {
      this.view.control = {
        ...this.view.control,
        loadingFertilizeOptions: false,
        fertilizeOptions: dto.fertilizes.map((fertilize) => ({
          id: fertilize.id,
          name: fertilize.name
        }))
      };
      return;
    }
    this.view.control = {
      ...this.view.control,
      loadingPesticideOptions: false,
      pesticideOptions: dto.pesticides.map((pesticide) => ({
        id: pesticide.id,
        name: pesticide.name
      }))
    };
  }

  onSuccess(dto: SaveWorkRecordSheetSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const mode = dto.mode;
    const saveToastContext = this.view.control.saveToastContext;
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
          saveToastContext
        )
      ),
      saveToastContext: null
    };
    this.view.close();
    this.onSavedCallback?.({
      workRecord: dto.workRecord,
      mode,
      saveToastContext
    });
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
    if (this.view.control.loadingFertilizeOptions) {
      this.view.control = {
        ...this.view.control,
        loadingFertilizeOptions: false
      };
      return;
    }
    if (this.view.control.loadingPesticideOptions) {
      this.view.control = {
        ...this.view.control,
        loadingPesticideOptions: false
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
        plannedGdd: dto.plannedGdd,
        gddDelta: dto.gddDelta,
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
