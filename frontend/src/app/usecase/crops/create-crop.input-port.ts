import { CreateCropInputDto } from './create-crop.dtos';

export interface CreateCropInputPort {
  execute(dto: CreateCropInputDto): void;
}
