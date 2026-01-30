import { Pest } from '../../../domain/pests/pest';

export type PestDetailViewState = {
  loading: boolean;
  error: string | null;
  pest: Pest | null;
};

export interface PestDetailView {
  get control(): PestDetailViewState;
  set control(value: PestDetailViewState);
  /** Reload detail (e.g. after undo restore). */
  reload(): void;
}