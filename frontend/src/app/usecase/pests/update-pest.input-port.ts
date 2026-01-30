import { UpdatePestInputDto } from './update-pest.dtos';

export interface UpdatePestInputPort {
  execute(dto: UpdatePestInputDto): void;
}