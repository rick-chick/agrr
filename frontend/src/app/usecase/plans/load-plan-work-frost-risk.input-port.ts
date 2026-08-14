import { LoadPlanWorkFrostRiskInputDto } from './load-plan-work-frost-risk.dtos';

export interface LoadPlanWorkFrostRiskInputPort {
  execute(dto: LoadPlanWorkFrostRiskInputDto): void;
}
