import { Farm } from '../../domain/farms/farm';
import { EntryScheduleCropsListResponse } from '../../domain/entry-schedule/entry-schedule';

export interface EntryScheduleFarmCropsViewState {
  farmLoading: boolean;
  selectedFarmId: number | null;
  selectedFarm: Farm | null;
  listResponse: EntryScheduleCropsListResponse | null;
  cropsLoading: boolean;
  cropsError: string | null;
  loadCursor: string | null;
}

export interface EntryScheduleFarmCropsView {
  get control(): EntryScheduleFarmCropsViewState;
  set control(value: EntryScheduleFarmCropsViewState);
  afterFarmResolved(farm: Farm): void;
  onInvalidFarm(): void;
}
