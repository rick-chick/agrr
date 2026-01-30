import { UpdateFarmInputDto } from './update-farm.dtos';

export interface UpdateFarmInputPort {
  execute(dto: UpdateFarmInputDto): void;
}
