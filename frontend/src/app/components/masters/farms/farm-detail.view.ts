import { Farm } from '../../../domain/farms/farm';
import { Field } from '../../../domain/farms/field';

export type FarmDetailViewState = {
  loading: boolean;
  error: string | null;
  farm: Farm | null;
  fields: Field[];
};

export interface FarmDetailView {
  get control(): FarmDetailViewState;
  set control(value: FarmDetailViewState);
  load?(farmId: number): void;
}
