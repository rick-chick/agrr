import { describe, expect, it } from 'vitest';
import { amountGroupSummaryAnchorId, bpAmountProposalAnchorId } from './amount-group-summary-anchor';

describe('amountGroupSummaryAnchorId', () => {
  it('builds a stable anchor id from stage_order, category, and task_type', () => {
    expect(amountGroupSummaryAnchorId(1, 'fertilizer', 'fertilize')).toBe(
      'plan-learn-amount-group-1-fertilizer-fertilize'
    );
  });

  it('uses none when stage_order is null', () => {
    expect(amountGroupSummaryAnchorId(null, 'general', 'field_work')).toBe(
      'plan-learn-amount-group-none-general-field_work'
    );
    expect(bpAmountProposalAnchorId(null, 'general', 'field_work')).toBe(
      'plan-learn-bp-amount-proposal-none-general-field_work'
    );
  });
});
