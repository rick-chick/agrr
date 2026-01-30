import { LoadPestForEditInputDto } from './load-pest-for-edit.dtos';

export interface LoadPestForEditInputPort {
  execute(dto: LoadPestForEditInputDto): void;
}