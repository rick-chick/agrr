import { DeletePlanInputDto } from './delete-plan.dtos';

export interface DeletePlanInputPort {
  execute(dto: DeletePlanInputDto): void;
}
