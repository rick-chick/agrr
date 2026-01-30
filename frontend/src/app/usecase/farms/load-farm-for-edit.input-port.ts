import { LoadFarmForEditInputDto } from './load-farm-for-edit.dtos';

export interface LoadFarmForEditInputPort {
  execute(dto: LoadFarmForEditInputDto): void;
}
