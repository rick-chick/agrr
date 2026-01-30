import { Farm } from '../../../domain/farms/farm';

export type FarmListViewState = {
  loading: boolean;
  error: string | null;
  farms: Farm[];
};

export interface FarmListView {
  get control(): FarmListViewState;
  set control(value: FarmListViewState);
}
