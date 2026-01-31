import { Injectable } from '@angular/core';
import { LoadPrivatePlanSelectCropContextOutputPort } from '../../usecase/private-plan-create/load-private-plan-select-crop-context.output-port';
import { PrivatePlanSelectCropContextDataDto } from '../../usecase/private-plan-create/load-private-plan-select-crop-context.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FlashMessageService } from '../../services/flash-message.service';
import { inject } from '@angular/core';

export interface LoadPrivatePlanSelectCropContextView {
  control: {
    loading: boolean;
    error: string | null;
    farm: any;
    totalArea: number;
    crops: any[];
  };
}

@Injectable()
export class LoadPrivatePlanSelectCropContextPresenter implements LoadPrivatePlanSelectCropContextOutputPort {
  private readonly flashMessage = inject(FlashMessageService);
  private view: LoadPrivatePlanSelectCropContextView | null = null;

  setView(view: LoadPrivatePlanSelectCropContextView): void {
    this.view = view;
  }

  present(dto: PrivatePlanSelectCropContextDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      farm: dto.farm,
      totalArea: dto.totalArea,
      crops: dto.crops
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