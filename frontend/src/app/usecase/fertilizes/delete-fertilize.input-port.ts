import { DeleteFertilizeInputDto } from './delete-fertilize.dtos';

export interface DeleteFertilizeInputPort {
  execute(dto: DeleteFertilizeInputDto): void;
}
