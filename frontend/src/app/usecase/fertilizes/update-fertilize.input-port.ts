import { UpdateFertilizeInputDto } from './update-fertilize.dtos';

export interface UpdateFertilizeInputPort {
  execute(dto: UpdateFertilizeInputDto): void;
}
