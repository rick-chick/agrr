import { Pesticide } from '../../domain/pesticides/pesticide';

export interface LoadCropPesticideListInputDto {
  cropId: number;
}

export interface CropPesticideListDataDto {
  pesticides: Pesticide[];
}
