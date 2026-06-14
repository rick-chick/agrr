import { Inject, Injectable } from '@angular/core';
import { forkJoin } from 'rxjs';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { WorkRecord } from '../../models/plans/work-record';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';
import { WORK_RECORD_GATEWAY, WorkRecordGateway } from './work-record-gateway';
import { LoadWorkRecordsInputDto, WorkRecordMonthGroupDto } from './load-work-records.dtos';
import { LoadWorkRecordsInputPort } from './load-work-records.input-port';
import {
  LOAD_WORK_RECORDS_OUTPUT_PORT,
  LoadWorkRecordsOutputPort
} from './load-work-records.output-port';

export function groupWorkRecordsByMonth(records: WorkRecord[]): WorkRecordMonthGroupDto[] {
  const sorted = [...records].sort((a, b) => b.actual_date.localeCompare(a.actual_date));
  const groups: WorkRecordMonthGroupDto[] = [];
  for (const rec of sorted) {
    const monthLabel = rec.actual_date.slice(0, 7);
    const last = groups[groups.length - 1];
    if (last?.monthLabel === monthLabel) {
      last.records.push(rec);
    } else {
      groups.push({ monthLabel, records: [rec] });
    }
  }
  return groups;
}

@Injectable()
export class LoadWorkRecordsUseCase implements LoadWorkRecordsInputPort {
  constructor(
    @Inject(LOAD_WORK_RECORDS_OUTPUT_PORT) private readonly outputPort: LoadWorkRecordsOutputPort,
    @Inject(WORK_RECORD_GATEWAY) private readonly workRecordGateway: WorkRecordGateway,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway
  ) {}

  execute(dto: LoadWorkRecordsInputDto): void {
    forkJoin({
      records: this.workRecordGateway.listWorkRecords(dto.planId),
      plan: this.planGateway.fetchPlan(dto.planId)
    }).subscribe({
      next: ({ records, plan }) => {
        this.outputPort.present({
          plan: { id: plan.id, name: plan.name ?? '' },
          groups: groupWorkRecordsByMonth(records.work_records)
        });
      },
      error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
