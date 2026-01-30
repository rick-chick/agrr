import { Farm } from '../../domain/farms/farm';
import { FarmSizeOption } from '../../domain/public-plans/farm-size-option';

export type PublicPlanCreateViewState = {
  loading: boolean;
  error: string | null;
  farms: Farm[];
  farmSizes: FarmSizeOption[];
};

export interface PublicPlanCreateView {
  get control(): PublicPlanCreateViewState;
  set control(value: PublicPlanCreateViewState);
}
