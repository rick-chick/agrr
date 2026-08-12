import { Inject, Injectable } from '@angular/core';
import { forkJoin, of } from 'rxjs';
import { ErrorDto } from '../../../domain/shared/error.dto';
import { FieldClimateGateway, FIELD_CLIMATE_GATEWAY } from './field-climate.gateway';
import {
  FetchFieldClimateDataRequestDto,
  LoadFieldClimateInputDto
} from './load-field-climate.dtos';
import { LoadFieldClimateInputPort } from './load-field-climate.input-port';
import {
  LoadFieldClimateOutputPort,
  LOAD_FIELD_CLIMATE_OUTPUT_PORT
} from './load-field-climate.output-port';
import { PLAN_GATEWAY, PlanGateway } from '../plan-gateway';
import { WORK_RECORD_GATEWAY, WorkRecordGateway } from '../work-record-gateway';
import {
  buildFieldClimateLatestImplementation,
  buildFieldClimateWorkDayMarkers
} from '../../../domain/plans/field-climate-work-records';
import {
  collectTaskScheduleItemsForField,
  taskScheduleVarianceByItemId
} from '../../../domain/plans/task-schedule-variance-lookup';

@Injectable()
export class LoadFieldClimateUseCase implements LoadFieldClimateInputPort {
  constructor(
    @Inject(LOAD_FIELD_CLIMATE_OUTPUT_PORT)
    private readonly outputPort: LoadFieldClimateOutputPort,
    @Inject(FIELD_CLIMATE_GATEWAY)
    private readonly fieldClimateGateway: FieldClimateGateway,
    @Inject(WORK_RECORD_GATEWAY)
    private readonly workRecordGateway: WorkRecordGateway,
    @Inject(PLAN_GATEWAY)
    private readonly planGateway: PlanGateway
  ) {}

  execute(dto: LoadFieldClimateInputDto): void {
    const request: FetchFieldClimateDataRequestDto = {
      fieldCultivationId: dto.fieldCultivationId,
      planType: dto.planType,
      displayStartDate: dto.displayStartDate,
      displayEndDate: dto.displayEndDate
    };

    const workbench$ =
      dto.planId != null
        ? forkJoin({
            workRecords: this.workRecordGateway.listWorkRecords(dto.planId, {
              field_cultivation_id: dto.fieldCultivationId
            }),
            taskSchedule: this.planGateway.getTaskSchedule(dto.planId, {
              scope: 'plan',
              field_cultivation_id: dto.fieldCultivationId
            })
          })
        : of(null);

    forkJoin({
      climate: this.fieldClimateGateway.fetchFieldClimateData(request),
      workbench: workbench$
    }).subscribe({
      next: ({ climate, workbench }) => {
        let workDayMarkers = [];
        let latestImplementation = null;
        if (workbench) {
          const scheduleItems = collectTaskScheduleItemsForField(
            workbench.taskSchedule.fields,
            dto.fieldCultivationId
          );
          const varianceByItemId = taskScheduleVarianceByItemId(scheduleItems);
          workDayMarkers = buildFieldClimateWorkDayMarkers(workbench.workRecords.work_records);
          latestImplementation = buildFieldClimateLatestImplementation(
            workbench.workRecords.work_records,
            varianceByItemId
          );
        }
        this.outputPort.present({
          climateData: climate,
          workDayMarkers,
          latestImplementation
        });
      },
      error: (err: Error & { error?: { error?: string; errors?: string[] } }) => {
        const errorDto: ErrorDto = {
          message:
            err?.error?.error ??
            err?.error?.errors?.join(', ') ??
            err?.message ??
            'plans.field_climate.load_unknown'
        };

        this.outputPort.onError(errorDto);
      }
    });
  }
}
