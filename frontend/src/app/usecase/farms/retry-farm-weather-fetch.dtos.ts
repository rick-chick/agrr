import { Farm } from '../../domain/farms/farm';

export type RetryFarmWeatherFetchInputDto = {
  farmId: number;
};

export type RetryFarmWeatherFetchSuccessDto = {
  farm: Farm;
};
