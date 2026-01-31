import { LoadPrivatePlanSelectCropContextInputDto } from './load-private-plan-select-crop-context.dtos';

export interface LoadPrivatePlanSelectCropContextInputPort {
  execute(dto: LoadPrivatePlanSelectCropContextInputDto): void;
}