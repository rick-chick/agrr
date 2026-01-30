import { Pest } from '../../../domain/pests/pest';

export type PestListViewState = {
  loading: boolean;
  error: string | null;
  pests: Pest[];
};

export interface PestListView {
  get control(): PestListViewState;
  set control(value: PestListViewState);
}
