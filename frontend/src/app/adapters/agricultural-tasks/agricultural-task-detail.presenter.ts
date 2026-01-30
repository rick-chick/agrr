import { Injectable, inject } from '@angular/core';
import { Router } from '@angular/router';
import { ErrorDto } from '../../domain/shared/error.dto';
import { AgriculturalTaskDetailView } from '../../components/masters/agricultural-tasks/agricultural-task-detail.view';
import { LoadAgriculturalTaskDetailOutputPort } from '../../usecase/agricultural-tasks/load-agricultural-task-detail.output-port';
import { LoadAgriculturalTaskDetailDataDto } from '../../usecase/agricultural-tasks/load-agricultural-task-detail.dtos';
import { DeleteAgriculturalTaskOutputPort } from '../../usecase/agricultural-tasks/delete-agricultural-task.output-port';
import { DeleteAgriculturalTaskSuccessDto } from '../../usecase/agricultural-tasks/delete-agricultural-task.dtos';
import { UndoToastService } from '../../services/undo-toast.service';

@Injectable()
export class AgriculturalTaskDetailPresenter implements LoadAgriculturalTaskDetailOutputPort, DeleteAgriculturalTaskOutputPort {
  private readonly undoToast = inject(UndoToastService);
  private readonly router = inject(Router);
  private view: AgriculturalTaskDetailView | null = null;

  setView(view: AgriculturalTaskDetailView): void {
    this.view = view;
  }

  present(dto: LoadAgriculturalTaskDetailDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      agriculturalTask: dto.agriculturalTask
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: dto.message,
      agriculturalTask: null
    };
  }

  onSuccess(dto: DeleteAgriculturalTaskSuccessDto): void {
    if (dto.undo) {
      this.undoToast.showWithUndo(
        dto.undo.toast_message,
        dto.undo.undo_path,
        dto.undo.undo_token,
        () => this.router.navigate(['/agricultural_tasks'])
      );
    }
  }
}