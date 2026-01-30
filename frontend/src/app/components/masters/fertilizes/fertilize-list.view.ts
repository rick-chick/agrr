import { Fertilize } from '../../../domain/fertilizes/fertilize';

export type FertilizeListViewState = {
  loading: boolean;
  error: string | null;
  fertilizes: Fertilize[];
};

export interface FertilizeListView {
  get control(): FertilizeListViewState;
  set control(value: FertilizeListViewState);
}
