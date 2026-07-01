import { Farm } from '../../../domain/farms/farm';
import { Field } from '../../../domain/farms/field';
import { PendingUndoToastRequest } from '../../../core/view-effects/pending-undo-toast-view.effects';

export type FarmDetailViewState = {
  loading: boolean;
  error: string | null;
  farm: Farm | null;
  fields: Field[];
  pendingUndoToast: PendingUndoToastRequest | null;
};

export interface FarmDetailView {
  get control(): FarmDetailViewState;
  set control(value: FarmDetailViewState);
  load?(farmId: number): void;
  /** Reload detail (e.g. after undo restore). */
  reload(): void;
}
