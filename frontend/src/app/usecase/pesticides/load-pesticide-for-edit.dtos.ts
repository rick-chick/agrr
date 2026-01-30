import { Pesticide } from '../../domain/pesticides/pesticide';

export interface LoadPesticideForEditInputDto {
  pesticideId: number;
}

export interface LoadPesticideForEditDataDto {
  pesticide: Pesticide;
}