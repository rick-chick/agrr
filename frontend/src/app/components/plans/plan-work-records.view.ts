import type { WorkRecordSaveImpactPanelView } from '../../domain/plans/work-record-save-impact';
import {
  WorkRecordMonthGroupDto,
  WorkRecordsPlanHeaderDto
} from '../../usecase/plans/load-work-records.dtos';

export interface PlanWorkRecordsViewState {
  loading: boolean;
  error: string | null;
  plan: WorkRecordsPlanHeaderDto | null;
  groups: WorkRecordMonthGroupDto[];
  recordSaveImpactPanel: WorkRecordSaveImpactPanelView | null;
  recordSaveImpactLoading: boolean;
  recordSaveImpactError: string | null;
}

export interface PlanWorkRecordsView {
  control: PlanWorkRecordsViewState;
}
