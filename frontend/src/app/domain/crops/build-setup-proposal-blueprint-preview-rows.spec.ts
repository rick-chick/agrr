import { describe, expect, it } from 'vitest';
import { buildSetupProposalBlueprintPreviewRows } from './build-setup-proposal-blueprint-preview-rows';

describe('buildSetupProposalBlueprintPreviewRows', () => {
  const preview = {
    intent: 'blueprint_amount_patch',
    task_schedule_blueprints: [
      { blueprint_id: 10, stage_order: 1, stage_name: '育苗', task_type: 'fertilize' },
      { blueprint_id: 11, stage_order: 2, stage_name: '定植', task_type: 'fertilize' }
    ]
  };

  it('marks only rows matching handoff stage_order as highlighted', () => {
    const rows = buildSetupProposalBlueprintPreviewRows(preview, 1);

    expect(rows).toHaveLength(2);
    expect(rows[0]?.highlighted).toBe(true);
    expect(rows[1]?.highlighted).toBe(false);
  });

  it('returns no highlights when handoff stage is unset', () => {
    const rows = buildSetupProposalBlueprintPreviewRows(preview, null);

    expect(rows.every((row) => !row.highlighted)).toBe(true);
  });
});
