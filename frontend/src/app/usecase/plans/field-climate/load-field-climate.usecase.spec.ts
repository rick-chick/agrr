import { of, throwError } from 'rxjs';
import { describe, it, expect } from 'vitest';
import { FieldCultivationClimateData } from '../../../domain/plans/field-cultivation-climate-data';
import { FieldClimateGateway } from './field-climate.gateway';
import { FieldClimatePresentationDto } from './load-field-climate.dtos';
import { LoadFieldClimateOutputPort } from './load-field-climate.output-port';
import { LoadFieldClimateUseCase } from './load-field-climate.usecase';
import { PlanGateway } from '../plan-gateway';
import { WorkRecordGateway } from '../work-record-gateway';

describe('LoadFieldClimateUseCase', () => {
  const sampleData: FieldCultivationClimateData = {
    success: true,
    field_cultivation: {
      id: 1,
      field_name: 'North Field',
      crop_name: 'Tomato',
      start_date: '2026-02-01',
      completion_date: '2026-05-30'
    },
    farm: {
      id: 2,
      name: 'Kawasaki Farm',
      latitude: 35.5,
      longitude: 139.7
    },
    crop_requirements: {
      base_temperature: 12,
      optimal_temperature_range: {
        min: 18,
        max: 28,
        low_stress: 15,
        high_stress: 33
      }
    },
    weather_data: [
      { date: '2026-02-01', temperature_max: 20.5, temperature_min: 9.3, temperature_mean: 14.9 }
    ],
    gdd_data: [
      {
        date: '2026-02-01',
        gdd: 2.9,
        cumulative_gdd: 2.9,
        temperature: 14.9,
        current_stage: '播種〜発芽'
      }
    ],
    stages: [
      {
        name: '播種〜発芽',
        order: 1,
        gdd_required: 75,
        cumulative_gdd_required: 75,
        optimal_temperature_min: 18,
        optimal_temperature_max: 28,
        low_stress_threshold: 15,
        high_stress_threshold: 33
      }
    ]
  };

  const workRecordGateway: WorkRecordGateway = {
    listWorkRecords: () => of({ work_records: [] }),
    createWorkRecord: () => of({ work_record: {} as never }),
    updateWorkRecord: () => of({ work_record: {} as never }),
    deleteWorkRecord: () => of({} as never),
    skipTaskScheduleItem: () => of({ item: { id: 1, status: 'skipped', cancelled_at: null } }),
    unskipTaskScheduleItem: () => of({ item: { id: 1, status: 'planned', cancelled_at: null } })
  };

  const planGateway = {
    fetchPlan: () => of({} as never),
    getTaskSchedule: () =>
      of({
        plan: {} as never,
        week: {} as never,
        milestones: [],
        fields: [],
        labels: {},
        minimap: {} as never
      })
  } as unknown as PlanGateway;

  it('passes gateway result to outputPort.present', () => {
    const gateway: FieldClimateGateway = {
      fetchFieldClimateData: () => of(sampleData)
    };

    let presented: FieldClimatePresentationDto | null = null;
    const outputPort: LoadFieldClimateOutputPort = {
      present: (dto) => {
        presented = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadFieldClimateUseCase(
      outputPort,
      gateway,
      workRecordGateway,
      planGateway
    );
    useCase.execute({ fieldCultivationId: 1, planType: 'private' });

    expect(presented).toEqual({
      climateData: sampleData,
      workDayMarkers: [],
      latestImplementation: null
    });
  });

  it('enriches presentation with workbench data when planId is provided', () => {
    const gateway: FieldClimateGateway = {
      fetchFieldClimateData: () => of(sampleData)
    };

    const workRecordsGateway: WorkRecordGateway = {
      ...workRecordGateway,
      listWorkRecords: () =>
        of({
          work_records: [
            {
              id: 1,
              cultivation_plan_id: 7,
              field_cultivation_id: 1,
              task_schedule_item_id: 5,
              agricultural_task_id: null,
              name: 'Weeding',
              task_type: null,
              actual_date: '2026-06-12',
              amount: null,
              amount_unit: null,
              time_spent_minutes: null,
              notes: null,
              created_at: '2026-06-12',
              updated_at: '2026-06-12',
              task_schedule_item: { id: 5, name: 'Weeding', scheduled_date: '2026-06-10' }
            }
          ]
        })
    };

    const planGatewayWithVariance = {
      getTaskSchedule: () =>
        of({
          plan: {} as never,
          week: {} as never,
          milestones: [],
          fields: [
            {
              id: 1,
              name: 'Field A',
              crop_name: 'Tomato',
              area_sqm: 100,
              field_cultivation_id: 1,
              crop_id: 1,
              schedules: {
                general: [{ item_id: 5, delta_days: 2, gdd_delta: 10.5 }],
                fertilizer: [],
                unscheduled: []
              }
            }
          ],
          labels: {},
          minimap: {} as never
        })
    } as unknown as PlanGateway;

    let presented: FieldClimatePresentationDto | null = null;
    const outputPort: LoadFieldClimateOutputPort = {
      present: (dto) => {
        presented = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadFieldClimateUseCase(
      outputPort,
      gateway,
      workRecordsGateway,
      planGatewayWithVariance
    );
    useCase.execute({ fieldCultivationId: 1, planType: 'private', planId: 7 });

    expect(presented?.workDayMarkers).toEqual([
      {
        actualDate: '2026-06-12',
        name: 'Weeding',
        taskScheduleItemId: 5
      }
    ]);
    expect(presented?.latestImplementation).toEqual({
      name: 'Weeding',
      deltaDaysLabel: '+2',
      gddDeltaLabel: '+10.5'
    });
  });

  it('forwards gateway errors to outputPort.onError', () => {
    const gateway: FieldClimateGateway = {
      fetchFieldClimateData: () => throwError(() => new Error('connection lost'))
    };

    let receivedError: { message: string } | null = null;
    const outputPort: LoadFieldClimateOutputPort = {
      present: () => {},
      onError: (dto) => {
        receivedError = dto;
      }
    };

    const useCase = new LoadFieldClimateUseCase(
      outputPort,
      gateway,
      workRecordGateway,
      planGateway
    );
    useCase.execute({ fieldCultivationId: 1, planType: 'public' });

    expect(receivedError).not.toBeNull();
    expect(receivedError?.message).toContain('connection lost');
  });
});
