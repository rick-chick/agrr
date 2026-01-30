import { CreatePestInputDto } from './create-pest.dtos';

export interface CreatePestInputPort {
  execute(dto: CreatePestInputDto): void;
}