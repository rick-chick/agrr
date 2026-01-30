import { LoadFertilizeForEditInputDto } from './load-fertilize-for-edit.dtos';

export interface LoadFertilizeForEditInputPort {
  execute(dto: LoadFertilizeForEditInputDto): void;
}
