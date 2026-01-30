import { DeleteFarmInputDto } from './delete-farm.dtos';

export interface DeleteFarmInputPort {
  execute(dto: DeleteFarmInputDto): void;
}
