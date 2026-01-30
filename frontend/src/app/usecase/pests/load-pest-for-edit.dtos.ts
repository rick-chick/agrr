import { Pest } from '../../domain/pests/pest';

export interface LoadPestForEditInputDto {
  pestId: number;
}

export interface LoadPestForEditDataDto {
  pest: Pest;
}