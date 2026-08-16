import { describe, expect, it } from 'vitest';
import {
  resolveCropIdForFieldCultivation,
  scheduleCategoryFromTaskType
} from './work-record-sheet-schedule';

describe('work-record-sheet-schedule', () => {
  it('maps fertilizer task types to fertilizer schedule category', () => {
    expect(scheduleCategoryFromTaskType('basal_fertilization')).toBe('fertilizer');
    expect(scheduleCategoryFromTaskType('topdress_fertilization')).toBe('fertilizer');
  });

  it('maps pest control task types to pest_control schedule category', () => {
    expect(scheduleCategoryFromTaskType('preventive_spray')).toBe('pest_control');
    expect(scheduleCategoryFromTaskType('curative_spray')).toBe('pest_control');
  });

  it('resolves crop_id from field cultivation id', () => {
    const cropId = resolveCropIdForFieldCultivation(
      [
        {
          id: 1,
          name: 'A',
          crop_name: 'Tomato',
          area_sqm: 100,
          field_cultivation_id: 5,
          crop_id: 42,
          schedules: { general: [], fertilizer: [], pest_control: [], unscheduled: [] }
        }
      ],
      5
    );
    expect(cropId).toBe(42);
  });
});
