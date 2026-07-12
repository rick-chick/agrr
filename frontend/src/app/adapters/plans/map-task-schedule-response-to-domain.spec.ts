import { describe, expect, it } from 'vitest';
import type { TaskScheduleItem } from '../../models/plans/task-schedule';
import { TaskScheduleResponse } from '../../models/plans/task-schedule';
import { mapTaskScheduleResponseToDomain } from './map-task-schedule-response-to-domain';

function task(
  overrides: Partial<TaskScheduleItem> & Pick<TaskScheduleItem, 'item_id' | 'name' | 'scheduled_date'>
): TaskScheduleItem {
  return {
    item_id: overrides.item_id,
    name: overrides.name,
    scheduled_date: overrides.scheduled_date,
    task_type: 'general',
    category: 'general',
    priority: 1,
    source: 'blueprint',
    weather_dependency: 'low',
    time_per_sqm: '0',
    amount: '',
    amount_unit: '',
    status: 'planned',
    agricultural_task_id: 1,
    field_cultivation_id: 10,
    completed: false,
    work_records: [],
    details: {
      stage: { name: 'Stage', order: 1 },
      gdd: { trigger: '100', tolerance: '10' },
      priority: 1,
      weather_dependency: 'low',
      time_per_sqm: '0',
      amount: '',
      amount_unit: '',
      source: 'blueprint',
      master: null,
      history: { rescheduled_at: null, cancelled_at: null }
    },
    badge: { type: 'planned' },
    ...overrides
  };
}

describe('mapTaskScheduleResponseToDomain', () => {
  it('maps API response to domain snapshot with list fields and details slice', () => {
    const response: TaskScheduleResponse = {
      plan: {
        id: 7,
        name: 'Main Plan',
        status: 'completed',
        planning_start_date: '2026-01-01',
        planning_end_date: '2026-12-31',
        timeline_generated_at: '2026-06-01T00:00:00Z',
        timeline_generated_at_display: '2026-06-01',
        task_schedule_sync_state: 'ready',
        task_schedule_sync_error: null,
        task_schedule_sync_error_crop_id: null
      },
      week: { start_date: '2026-06-01', end_date: '2026-06-07', label: '2026-06-01' },
      milestones: [],
      fields: [
        {
          id: 1,
          name: 'North',
          crop_name: 'Tomato',
          area_sqm: 100,
          field_cultivation_id: 10,
          crop_id: 20,
          schedules: {
            general: [task({ item_id: 1, name: 'Weeding', scheduled_date: '2026-06-10' })],
            fertilizer: [],
            unscheduled: []
          }
        }
      ],
      labels: {},
      minimap: { start_date: '', end_date: '', weeks: [] }
    };

    const snapshot = mapTaskScheduleResponseToDomain(response);

    expect(snapshot).toEqual({
      plan: { id: 7, name: 'Main Plan' },
      fields: [
        {
          name: 'North',
          crop_name: 'Tomato',
          field_cultivation_id: 10,
          schedules: {
            general: [
              {
                item_id: 1,
                name: 'Weeding',
                scheduled_date: '2026-06-10',
                status: 'planned',
                details: {
                  stageName: 'Stage',
                  gddTrigger: '100',
                  gddTolerance: '10',
                  amount: null,
                  amountUnit: null,
                  masterName: null,
                  masterDescription: null
                }
              }
            ],
            fertilizer: []
          }
        }
      ]
    });
  });

  it('maps details fields from API task item', () => {
    const response: TaskScheduleResponse = {
      plan: {
        id: 7,
        name: 'Main Plan',
        status: 'completed',
        planning_start_date: '2026-01-01',
        planning_end_date: '2026-12-31',
        timeline_generated_at: '2026-06-01T00:00:00Z',
        timeline_generated_at_display: '2026-06-01',
        task_schedule_sync_state: 'ready',
        task_schedule_sync_error: null,
        task_schedule_sync_error_crop_id: null
      },
      week: { start_date: '2026-06-01', end_date: '2026-06-07', label: '2026-06-01' },
      milestones: [],
      fields: [
        {
          id: 1,
          name: 'North',
          crop_name: 'Tomato',
          area_sqm: 100,
          field_cultivation_id: 10,
          crop_id: 20,
          schedules: {
            general: [
              task({
                item_id: 1,
                name: 'Fertilize',
                scheduled_date: '2026-06-10',
                details: {
                  stage: { name: 'Vegetative', order: 2 },
                  gdd: { trigger: '150', tolerance: '5' },
                  priority: 1,
                  weather_dependency: 'low',
                  time_per_sqm: '0',
                  amount: '20',
                  amount_unit: 'kg',
                  source: 'blueprint',
                  master: {
                    name: 'Fertilizer master',
                    description: 'Apply fertilizer evenly',
                    time_per_sqm: '0',
                    weather_dependency: 'low',
                    required_tools: [],
                    skill_level: 'beginner',
                    task_type: 'fertilizer'
                  },
                  history: { rescheduled_at: null, cancelled_at: null }
                }
              })
            ],
            fertilizer: [],
            unscheduled: []
          }
        }
      ],
      labels: {},
      minimap: { start_date: '', end_date: '', weeks: [] }
    };

    const snapshot = mapTaskScheduleResponseToDomain(response);
    const item = snapshot.fields[0]?.schedules.general[0];

    expect(item?.details).toEqual({
      stageName: 'Vegetative',
      gddTrigger: '150',
      gddTolerance: '5',
      amount: '20',
      amountUnit: 'kg',
      masterName: 'Fertilizer master',
      masterDescription: 'Apply fertilizer evenly'
    });
  });
});
