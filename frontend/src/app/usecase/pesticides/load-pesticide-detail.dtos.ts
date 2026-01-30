import { Pesticide } from '../../domain/pesticides/pesticide';

export interface LoadPesticideDetailInputDto {
  pesticideId: number;
}

export interface PesticideDetailDataDto {
  pesticide: Pesticide;
}