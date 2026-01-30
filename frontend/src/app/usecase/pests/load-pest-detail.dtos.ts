import { Pest } from '../../domain/pests/pest';

export interface LoadPestDetailInputDto {
  pestId: number;
}

export interface PestDetailDataDto {
  pest: Pest;
}