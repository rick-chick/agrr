import { Pesticide } from '../../../domain/pesticides/pesticide';

export type PesticideListViewState = {
  loading: boolean;
  error: string | null;
  pesticides: Pesticide[];
};

export interface PesticideListView {
  get control(): PesticideListViewState;
  set control(value: PesticideListViewState);
}
