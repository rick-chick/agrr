import { CreatePesticideInputDto } from './create-pesticide.dtos';

export interface CreatePesticideInputPort {
  execute(dto: CreatePesticideInputDto): void;
}