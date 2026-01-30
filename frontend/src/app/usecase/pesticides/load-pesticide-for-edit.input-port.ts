import { LoadPesticideForEditInputDto } from './load-pesticide-for-edit.dtos';

export interface LoadPesticideForEditInputPort {
  execute(dto: LoadPesticideForEditInputDto): void;
}