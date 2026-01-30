import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { AgriculturalTaskCreateView } from '../../components/masters/agricultural-tasks/agricultural-task-create.view';
import { CreateAgriculturalTaskOutputPort } from '../../usecase/agricultural-tasks/create-agricultural-task.output-port';
import { CreateAgriculturalTaskSuccessDto } from '../../usecase/agricultural-tasks/create-agricultural-task.dtos';
import { FlashMessageService } from '../../services/flash-message.service';

@Injectable()
export class AgriculturalTaskCreatePresenter implements CreateAgriculturalTaskOutputPort {
  private readonly flashMessage = inject(FlashMessageService);
  private view: AgriculturalTaskCreateView | null = null;

  setView(view: AgriculturalTaskCreateView): void {
    this.view = view;
  }

  onSuccess(_dto: CreateAgriculturalTaskSuccessDto): void {}

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.flashMessage.show({ type: 'error', text: dto.message });
    this.view.control = {
      ...this.view.control,
      saving: false,
      error: null
    };
  }
}