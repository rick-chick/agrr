import { Injectable, inject } from '@angular/core';
import { UpdateFieldOutputPort } from '../../usecase/farms/update-field.output-port';
import { FarmDetailView } from '../../components/masters/farms/farm-detail.view';
import { UpdateFieldOutputDto } from '../../usecase/farms/update-field.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FlashMessageService } from '../../services/flash-message.service';

@Injectable()
export class UpdateFieldPresenter implements UpdateFieldOutputPort {
  private readonly flashMessage = inject(FlashMessageService);
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
    this.flashMessage.show({ type: 'error', text: dto.message });
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null
    };
  }
}