import type { PlanSaveImpactViewFields } from '../../adapters/plans/plan-save-impact.presenter.helpers';
import {
  WorkRecordMonthGroupDto,
  WorkRecordsPlanHeaderDto
} from '../../usecase/plans/load-work-records.dtos';

export interface PlanWorkRecordsViewState extends PlanSaveImpactViewFields {
  loading: boolean;
  error: string | null;
  plan: WorkRecordsPlanHeaderDto | null;
  groups: WorkRecordMonthGroupDto[];
}

export interface PlanWorkRecordsView {
  control: PlanWorkRecordsViewState;
}
