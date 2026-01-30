import { LoadPestDetailInputDto } from './load-pest-detail.dtos';

export interface LoadPestDetailInputPort {
  execute(dto: LoadPestDetailInputDto): void;
}