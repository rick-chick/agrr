import { Farm } from '../../domain/farms/farm';

export interface LoadPublicPlanFarmsInputDto {
  region: string;
}

export interface PublicPlanFarmsDataDto {
  farms: Farm[];
}
