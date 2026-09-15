import { Injectable } from '@angular/core';
import { EntryScheduleDetailView } from '../../components/entry-schedule/entry-schedule-detail.view';
import { LoadEntryScheduleCropOutputPort } from '../../usecase/entry-schedule/load-entry-schedule-crop.output-port';
import { EntryScheduleCropDataDto } from '../../usecase/entry-schedule/load-entry-schedule-crop.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { masterLoadErrorFromDto } from '../masters/master-load-error-presenter.helpers';

@Injectable()
export class EntryScheduleDetailPresenter implements LoadEntryScheduleCropOutputPort {
  private view: EntryScheduleDetailView | null = null;

  setView(view: EntryScheduleDetailView): void {
    this.view = view;
  }

  present(dto: EntryScheduleCropDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      errorKey: null,
      errorIsWarmup: false,
      warmupMessageKey: null,
      data: dto.data
    };
    this.view.onCropLoaded(dto.data.crop.id, dto.data.crop.name);
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const { errorKey, isWarmupError } = masterLoadErrorFromDto(dto);
    this.view.control = {
      ...this.view.control,
      loading: false,
      errorKey,
      errorIsWarmup: isWarmupError,
      warmupMessageKey: isWarmupError ? errorKey : null,
      data: null
    };
    this.view.onCropLoadFailed();
  }
}
