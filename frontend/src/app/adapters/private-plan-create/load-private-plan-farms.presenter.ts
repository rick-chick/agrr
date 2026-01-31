import { Injectable } from '@angular/core';
import { LoadPrivatePlanFarmsOutputPort } from '../../usecase/private-plan-create/load-private-plan-farms.output-port';
import { PrivatePlanFarmsDataDto } from '../../usecase/private-plan-create/load-private-plan-farms.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FlashMessageService } from '../../services/flash-message.service';
import { inject } from '@angular/core';

export interface LoadPrivatePlanFarmsView {
  control: {
    loading: boolean;
    error: string | null;
    farms: any[];
  };
}

@Injectable()
export class LoadPrivatePlanFarmsPresenter implements LoadPrivatePlanFarmsOutputPort {
  private readonly flashMessage = inject(FlashMessageService);
  private view: LoadPrivatePlanFarmsView | null = null;

  setView(view: LoadPrivatePlanFarmsView): void {
    this.view = view;
  }

  present(dto: PrivatePlanFarmsDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      farms: dto.farms
    };
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