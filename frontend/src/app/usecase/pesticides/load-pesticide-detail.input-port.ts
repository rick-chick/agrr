import { LoadPesticideDetailInputDto } from './load-pesticide-detail.dtos';

export interface LoadPesticideDetailInputPort {
  execute(dto: LoadPesticideDetailInputDto): void;
}