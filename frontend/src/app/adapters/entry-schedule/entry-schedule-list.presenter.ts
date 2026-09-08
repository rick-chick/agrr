import { Injectable } from '@angular/core';
import { EntryScheduleListView } from '../../components/entry-schedule/entry-schedule-list.view';
import { LoadEntryScheduleFarmsOutputPort } from '../../usecase/entry-schedule/load-entry-schedule-farms.output-port';
import { EntryScheduleFarmsDataDto } from '../../usecase/entry-schedule/load-entry-schedule-farms.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

@Injectable()
export class EntryScheduleListPresenter implements LoadEntryScheduleFarmsOutputPort {
  private view: EntryScheduleListView | null = null;

  setView(view: EntryScheduleListView): void {
    this.view = view;
  }

  present(dto: EntryScheduleFarmsDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      farmsLoading: false,
      farmsError: null,
      farms: dto.farms
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      farmsLoading: false,
      farmsError: dto.message,
      farms: []
    };
  }
}
