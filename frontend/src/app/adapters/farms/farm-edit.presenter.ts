import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FarmEditView } from '../../components/masters/farms/farm-edit.view';
import { LoadFarmForEditOutputPort } from '../../usecase/farms/load-farm-for-edit.output-port';
import { LoadFarmForEditDataDto } from '../../usecase/farms/load-farm-for-edit.dtos';
import { UpdateFarmOutputPort } from '../../usecase/farms/update-farm.output-port';
import { UpdateFarmSuccessDto } from '../../usecase/farms/update-farm.dtos';
import { FlashMessageService } from '../../services/flash-message.service';

@Injectable()
export class FarmEditPresenter implements LoadFarmForEditOutputPort, UpdateFarmOutputPort {
  private readonly flashMessage = inject(FlashMessageService);
  private view: FarmEditView | null = null;

  setView(view: FarmEditView): void {
    this.view = view;
  }

  present(dto: LoadFarmForEditDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      saving: false,
      formData: {
        name: dto.farm.name,
        region: dto.farm.region,
        latitude: dto.farm.latitude,
        longitude: dto.farm.longitude
      }
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.flashMessage.show({ type: 'error', text: dto.message });
    this.view.control = {
      ...this.view.control,
      loading: false,
      saving: false,
      error: null
    };
  }

  onSuccess(_dto: UpdateFarmSuccessDto): void {
    // Navigation is handled by Component's onSuccess callback
  }
}
