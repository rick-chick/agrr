import { CreateFertilizeInputDto } from './create-fertilize.dtos';

export interface CreateFertilizeInputPort {
  execute(dto: CreateFertilizeInputDto): void;
}
