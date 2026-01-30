import { LoadCropForEditInputDto } from './load-crop-for-edit.dtos';

export interface LoadCropForEditInputPort {
  execute(dto: LoadCropForEditInputDto): void;
}
