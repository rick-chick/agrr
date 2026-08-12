import { describe, expect, it } from 'vitest';
import {
  applyPlanSaveImpactSummary,
  beginPlanSaveImpactLoad,
  planSaveImpactErrorFields
} from './plan-save-impact.presenter.helpers';

describe('plan-save-impact presenter helpers', () => {
  it('begins save impact load with cleared panel state', () => {
    const result = beginPlanSaveImpactLoad(
      {
        event: {
          workRecord: {
            id: 1,
            cultivation_plan_id: 7,
            field_cultivation_id: 10,
            task_schedule_item_id: 5,
            agricultural_task_id: null,
            name: 'Weeding',
            task_type: null,
            actual_date: '2026-06-13',
            amount: null,
            amount_unit: null,
            time_spent_minutes: null,
            notes: null,
            created_at: '2026-06-13',
            updated_at: '2026-06-13',
            task_schedule_item: { id: 5, name: 'Weeding', scheduled_date: '2026-06-10' },
            gdd_at_actual: 130.5
          },
          mode: 'create-from-item'
        },
        context: { planId: 7, fieldCultivationId: 10, taskScheduleItemId: 5, gddTrigger: 100 }
      },
      2
    );

    expect(result.loadGeneration).toBe(2);
    expect(result.fields).toEqual({
      saveImpact: null,
      saveImpactLoading: true,
      saveImpactError: null
    });
  });

  it('builds save impact from summary when load generation matches', () => {
    const applied = applyPlanSaveImpactSummary(
      {
        event: {
          workRecord: {
            id: 1,
            cultivation_plan_id: 7,
            field_cultivation_id: 10,
            task_schedule_item_id: 5,
            agricultural_task_id: null,
            name: 'Weeding',
            task_type: null,
            actual_date: '2026-06-13',
            amount: null,
            amount_unit: null,
            time_spent_minutes: null,
            notes: null,
            created_at: '2026-06-13',
            updated_at: '2026-06-13',
            task_schedule_item: { id: 5, name: 'Weeding', scheduled_date: '2026-06-10' },
            gdd_at_actual: 130.5
          },
          mode: 'create-from-item'
        },
        context: { planId: 7, fieldCultivationId: 10, taskScheduleItemId: 5, gddTrigger: 100 }
      },
      3,
      3,
      {
        loadGeneration: 3,
        summary: {
          plan_id: 7,
          unrecorded_count: 4,
          categories: [
            {
              category: 'general',
              average_delta_days: 2.5,
              item_count: 5,
              recorded_count: 3
            }
          ],
          top_variance_items: []
        }
      }
    );

    expect(applied?.pending).toBeNull();
    expect(applied?.fields.saveImpact).toEqual({
      taskName: 'Weeding',
      deltaDays: '+3',
      gddDelta: '+30.5',
      planStats: {
        completedCount: 3,
        averageDeltaDays: 2.5,
        unrecordedCount: 4
      }
    });
    expect(applied?.fields.saveImpactLoading).toBe(false);
  });

  it('ignores stale summary responses', () => {
    expect(
      applyPlanSaveImpactSummary(
        {
          event: {
            workRecord: {
              id: 1,
              cultivation_plan_id: 7,
              field_cultivation_id: null,
              task_schedule_item_id: null,
              agricultural_task_id: null,
              name: 'Extra',
              task_type: null,
              actual_date: '2026-06-13',
              amount: null,
              amount_unit: null,
              time_spent_minutes: null,
              notes: null,
              created_at: '2026-06-13',
              updated_at: '2026-06-13',
              task_schedule_item: null
            },
            mode: 'create-adhoc'
          },
          context: null
        },
        2,
        3,
        {
          loadGeneration: 2,
          summary: {
            plan_id: 7,
            unrecorded_count: 0,
            categories: [],
            top_variance_items: []
          }
        }
      )
    ).toBeNull();
  });

  it('maps save impact errors to view fields', () => {
    expect(planSaveImpactErrorFields('common.api_error.generic')).toEqual({
      saveImpact: null,
      saveImpactLoading: false,
      saveImpactError: 'common.api_error.generic'
    });
  });
});
