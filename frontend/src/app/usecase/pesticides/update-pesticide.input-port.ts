import { UpdatePesticideInputDto } from './update-pesticide.dtos';

export interface UpdatePesticideInputPort {
  execute(dto: UpdatePesticideInputDto): void;
}