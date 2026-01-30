import { DeletePesticideInputDto } from './delete-pesticide.dtos';

export interface DeletePesticideInputPort {
  execute(dto: DeletePesticideInputDto): void;
}