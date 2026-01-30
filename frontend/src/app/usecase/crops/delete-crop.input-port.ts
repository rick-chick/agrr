import { DeleteCropInputDto } from './delete-crop.dtos';

export interface DeleteCropInputPort {
  execute(dto: DeleteCropInputDto): void;
}
