import { describe, expect, it } from 'vitest';
import {
  buildPlanWorkDeepLinkQuery,
  resolvePlanWorkHighlightItemId
} from './build-plan-work-deep-link-query';

describe('resolvePlanWorkHighlightItemId', () => {
  it('returns the first unrecorded task item id', () => {
    expect(
      resolvePlanWorkHighlightItemId([
        { item: { item_id: 11 } },
        { item: { item_id: 12 } }
      ])
    ).toBe(11);
  });

  it('returns null when no unrecorded rows exist', () => {
    expect(resolvePlanWorkHighlightItemId([])).toBeNull();
  });
});

describe('buildPlanWorkDeepLinkQuery', () => {
  it('builds highlight_item query for work deep link', () => {
    expect(buildPlanWorkDeepLinkQuery(42)).toEqual({ highlight_item: 42 });
  });

  it('returns null when there is no highlight target', () => {
    expect(buildPlanWorkDeepLinkQuery(null)).toBeNull();
  });
});
