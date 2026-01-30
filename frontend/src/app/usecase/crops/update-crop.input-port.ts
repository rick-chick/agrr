import { UpdateCropInputDto } from './update-crop.dtos';

export interface UpdateCropInputPort {
  execute(dto: UpdateCropInputDto): void;
}
