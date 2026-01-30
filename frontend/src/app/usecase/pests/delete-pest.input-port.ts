import { DeletePestInputDto } from './delete-pest.dtos';

export interface DeletePestInputPort {
  execute(dto: DeletePestInputDto): void;
}