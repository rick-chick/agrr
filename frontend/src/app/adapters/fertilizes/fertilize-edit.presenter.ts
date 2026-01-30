import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FertilizeEditView } from '../../components/masters/fertilizes/fertilize-edit.view';
import { LoadFertilizeForEditOutputPort } from '../../usecase/fertilizes/load-fertilize-for-edit.output-port';
import { LoadFertilizeForEditDataDto } from '../../usecase/fertilizes/load-fertilize-for-edit.dtos';
import { UpdateFertilizeOutputPort } from '../../usecase/fertilizes/update-fertilize.output-port';
import { UpdateFertilizeSuccessDto } from '../../usecase/fertilizes/update-fertilize.dtos';
import { FlashMessageService } from '../../services/flash-message.service';

@Injectable()
export class FertilizeEditPresenter
  implements LoadFertilizeForEditOutputPort, UpdateFertilizeOutputPort
{
  private readonly flashMessage = inject(FlashMessageService);
  private view: FertilizeEditView | null = null;

  setView(view: FertilizeEditView): void {
    this.view = view;
  }

  present(dto: LoadFertilizeForEditDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const f = dto.fertilize;
    this.view.control = {
      loading: false,
      error: null,
      saving: false,
      formData: {
        name: f.name,
        n: f.n ?? null,
        p: f.p ?? null,
        k: f.k ?? null,
        description: f.description ?? null,
        package_size: f.package_size ?? null,
        region: f.region ?? null
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

  onSuccess(_dto: UpdateFertilizeSuccessDto): void {}
}
