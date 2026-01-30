import { LoadFertilizeDetailInputDto } from './load-fertilize-detail.dtos';

export interface LoadFertilizeDetailInputPort {
  execute(dto: LoadFertilizeDetailInputDto): void;
}
