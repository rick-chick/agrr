import { CreateFarmInputDto } from './create-farm.dtos';

export interface CreateFarmInputPort {
  execute(dto: CreateFarmInputDto): void;
}
