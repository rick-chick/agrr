import { LoadCropPesticideListInputDto } from './load-crop-pesticide-list.dtos';

export interface LoadCropPesticideListInputPort {
  execute(dto: LoadCropPesticideListInputDto): void;
}
