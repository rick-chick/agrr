import { LoadFarmDetailInputDto } from './load-farm-detail.dtos';

export interface LoadFarmDetailInputPort {
  execute(dto: LoadFarmDetailInputDto): void;
}
