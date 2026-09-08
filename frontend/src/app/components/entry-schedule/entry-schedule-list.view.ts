import { Farm } from '../../domain/farms/farm';

export interface EntryScheduleListViewState {
  farmsLoading: boolean;
  farmsError: string | null;
  farms: Farm[];
}

export interface EntryScheduleListView {
  get control(): EntryScheduleListViewState;
  set control(value: EntryScheduleListViewState);
}
