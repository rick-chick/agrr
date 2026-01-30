import { Fertilize } from '../../../domain/fertilizes/fertilize';

export type FertilizeDetailViewState = {
  loading: boolean;
  error: string | null;
  fertilize: Fertilize | null;
};

export interface FertilizeDetailView {
  get control(): FertilizeDetailViewState;
  set control(value: FertilizeDetailViewState);
}
