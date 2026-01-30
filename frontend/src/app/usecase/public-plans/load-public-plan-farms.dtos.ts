import { Farm } from '../../domain/farms/farm';
import { FarmSizeOption } from '../../domain/public-plans/farm-size-option';

export interface LoadPublicPlanFarmsInputDto {
  region: string;
}

export interface PublicPlanFarmsDataDto {
  farms: Farm[];
  farmSizes: FarmSizeOption[];
}
