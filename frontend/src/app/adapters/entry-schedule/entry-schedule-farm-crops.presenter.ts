import { Injectable } from '@angular/core';
import { EntryScheduleCropListItem } from '../../domain/entry-schedule/entry-schedule';
import { EntryScheduleFarmCropsView } from '../../components/entry-schedule/entry-schedule-farm-crops.view';
import { LoadEntryScheduleCropsOutputPort } from '../../usecase/entry-schedule/load-entry-schedule-crops.output-port';
import { EntryScheduleCropsDataDto } from '../../usecase/entry-schedule/load-entry-schedule-crops.dtos';
import { ResolveEntryScheduleFarmOutputPort } from '../../usecase/entry-schedule/resolve-entry-schedule-farm.output-port';
import { ResolveEntryScheduleFarmDataDto } from '../../usecase/entry-schedule/resolve-entry-schedule-farm.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

@Injectable()
export class EntryScheduleFarmCropsPresenter
  implements LoadEntryScheduleCropsOutputPort, ResolveEntryScheduleFarmOutputPort
{
  private view: EntryScheduleFarmCropsView | null = null;

  setView(view: EntryScheduleFarmCropsView): void {
    this.view = view;
  }

  presentFarm(dto: ResolveEntryScheduleFarmDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      farmLoading: false,
      selectedFarmId: dto.farm.id,
      selectedFarm: dto.farm
    };
    this.view.afterFarmResolved(dto.farm);
  }

  onInvalidFarm(): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      farmLoading: false
    };
    this.view.onInvalidFarm();
  }

  present(dto: EntryScheduleCropsDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const { response, append } = dto;
    const loadCursor = response.meta?.next_cursor ?? null;

    if (append && this.view.control.listResponse) {
      const prev = this.view.control.listResponse;
      const merged: EntryScheduleCropListItem[] = [...prev.crops, ...response.crops];
      this.view.control = {
        ...this.view.control,
        cropsLoading: false,
        cropsError: null,
        listResponse: {
          ...response,
          crops: merged,
          farm: response.farm,
          prediction: response.prediction,
          meta: response.meta
        },
        loadCursor
      };
    } else {
      this.view.control = {
        ...this.view.control,
        cropsLoading: false,
        cropsError: null,
        listResponse: response,
        loadCursor
      };
    }
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      cropsLoading: false,
      cropsError: dto.message
    };
  }
}
