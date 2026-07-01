import { Injectable } from '@angular/core';
import { UpdateFieldOutputPort } from '../../usecase/farms/update-field.output-port';
import { FarmDetailView } from '../../components/masters/farms/farm-detail.view';
import { UpdateFieldOutputDto } from '../../usecase/farms/update-field.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { pendingErrorFlashFromError } from '../../core/view-effects/pending-error-flash-presenter.helpers';

@Injectable()
export class UpdateFieldPresenter implements UpdateFieldOutputPort {
  private view: FarmDetailView | null = null;

  setView(view: FarmDetailView): void {
    this.view = view;
  }

  present(dto: UpdateFieldOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    // 更新成功時は一覧を再取得
    if (dto.field.farm_id) {
      this.view.load?.(dto.field.farm_id);
    }
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      pendingErrorFlash: pendingErrorFlashFromError(dto)
    };
  }
}