import {
  WorkRecordMonthGroupDto,
  WorkRecordsPlanHeaderDto
} from '../../usecase/plans/load-work-records.dtos';

export interface PlanWorkRecordsViewState {
  loading: boolean;
  error: string | null;
  plan: WorkRecordsPlanHeaderDto | null;
  groups: WorkRecordMonthGroupDto[];
}

export interface PlanWorkRecordsView {
  control: PlanWorkRecordsViewState;
}
