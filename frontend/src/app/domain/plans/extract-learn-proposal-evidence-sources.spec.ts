import { describe, expect, it } from 'vitest';
import { extractLearnProposalEvidenceSources } from './extract-learn-proposal-evidence-sources';
import type { PlanFieldSchedule } from '../work-schedule/plan-schedule-snapshot';

const fields: PlanFieldSchedule[] = [
  {
    id: 1,
    name: 'North bed',
    crop_name: 'Tomato',
    crop_id: 42,
    field_cultivation_id: 10,
    schedules: {
      general: [
        {
          item_id: 100,
          name: 'Transplant',
          scheduled_date: '2025-04-01',
          actualDate: '2025-04-10',
          deltaDays: 5,
          gddTrigger: 100,
          gddAtActual: 115,
          gddDelta: 15,
          stageOrder: 1,
          category: 'general',
          status: 'completed',
          completed: true,
          details: {
            stageName: 'Vegetative',
            amount: null,
            amountUnit: null,
            masterDescription: null
          }
        }
      ],
      fertilizer: [],
      pest_control: [],
      unscheduled: []
    }
  }
];

describe('extractLearnProposalEvidenceSources', () => {
  it('maps flattened schedule rows with crop id, category, and stage order', () => {
    expect(extractLearnProposalEvidenceSources(fields)).toEqual([
      {
        cropId: 42,
        category: 'general',
        stageOrder: 1,
        name: 'Transplant',
        actualDate: '2025-04-10',
        deltaDays: 5,
        gddDelta: 15,
        status: 'completed'
      }
    ]);
  });
});
