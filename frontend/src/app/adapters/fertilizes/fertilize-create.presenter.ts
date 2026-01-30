import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FertilizeCreateView } from '../../components/masters/fertilizes/fertilize-create.view';
import { CreateFertilizeOutputPort } from '../../usecase/fertilizes/create-fertilize.output-port';
import { CreateFertilizeSuccessDto } from '../../usecase/fertilizes/create-fertilize.dtos';
import { FlashMessageService } from '../../services/flash-message.service';

@Injectable()
export class FertilizeCreatePresenter implements CreateFertilizeOutputPort {
  private readonly flashMessage = inject(FlashMessageService);
  private view: FertilizeCreateView | null = null;

  setView(view: FertilizeCreateView): void {
    this.view = view;
  }

  onSuccess(_dto: CreateFertilizeSuccessDto): void {}

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
