import { LoadPlanVsActualSummaryInputDto } from './load-plan-vs-actual-summary.dtos';

export interface LoadPlanVsActualSummaryInputPort {
  execute(dto: LoadPlanVsActualSummaryInputDto): void;
}
