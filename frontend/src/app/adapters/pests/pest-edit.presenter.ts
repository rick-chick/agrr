import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { errorDtoI18nKey } from '../../core/error-dto-i18n-key';
import { masterLoadErrorFromDto } from '../masters/master-load-error-presenter.helpers';
import { PestEditView } from '../../components/masters/pests/pest-edit.view';
import { LoadPestForEditOutputPort } from '../../usecase/pests/load-pest-for-edit.output-port';
import { LoadPestForEditDataDto } from '../../usecase/pests/load-pest-for-edit.dtos';
import { UpdatePestOutputPort } from '../../usecase/pests/update-pest.output-port';
import { UpdatePestSuccessDto } from '../../usecase/pests/update-pest.dtos';
import { pendingErrorFlashFromError } from '../../core/view-effects/pending-error-flash-presenter.helpers';

@Injectable()
export class PestEditPresenter implements LoadPestForEditOutputPort, UpdatePestOutputPort {
  private view: PestEditView | null = null;

  setView(view: PestEditView): void {
    this.view = view;
  }

  present(dto: LoadPestForEditDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const pest = dto.pest;
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      errorIsWarmup: false,
      formData: {
        name: pest.name,
        name_scientific: pest.name_scientific ?? null,
        family: pest.family ?? null,
        order: pest.order ?? null,
        description: pest.description ?? null,
        occurrence_season: pest.occurrence_season ?? null,
        region: pest.region ?? null
      }
    ,
      pendingErrorFlash: null
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (this.view.control.loading) {
      const { errorKey, isWarmupError } = masterLoadErrorFromDto(dto);
      this.view.control = {
        ...this.view.control,
        loading: false,
        saving: false,
        error: errorKey,
        errorIsWarmup: isWarmupError,
        pendingErrorFlash: null
      };
      return;
    }
    this.view.control = {
      ...this.view.control,
      loading: false,
      saving: false,
      error: null,
      errorIsWarmup: false,
      pendingErrorFlash: pendingErrorFlashFromError({ message: errorDtoI18nKey(dto) })
    };
  }

  onSuccess(_dto: UpdatePestSuccessDto): void {}
}