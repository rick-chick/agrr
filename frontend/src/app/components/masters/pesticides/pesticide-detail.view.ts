import { Pesticide } from '../../../domain/pesticides/pesticide';

export type PesticideDetailViewState = {
  loading: boolean;
  error: string | null;
  pesticide: Pesticide | null;
};

export interface PesticideDetailView {
  get control(): PesticideDetailViewState;
  set control(value: PesticideDetailViewState);
}