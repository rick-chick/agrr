import { describe, expect, it } from 'vitest';
import {
  applyResolvedUrl,
  type ResolvedCaptureIds
} from '../../../../e2e/shared/apply-resolved-url';

const baseIds: ResolvedCaptureIds = {
  masters: { crops: 42, farms: 7 },
  privatePlanId: 99,
  publicPlanId: 3,
  farmId: 7,
  cropId: 15
};

describe('applyResolvedUrl', () => {
  it('resolves plans/:id/work with private plan id', () => {
    expect(applyResolvedUrl('plans/:id/work', '/plans/1/work', baseIds)).toBe('/plans/99/work');
  });

  it('resolves plans/:id/work_records with private plan id', () => {
    expect(applyResolvedUrl('plans/:id/work_records', '/plans/1/work_records', baseIds)).toBe(
      '/plans/99/work_records'
    );
  });

  it('leaves plan sub-routes unchanged when privatePlanId is null', () => {
    const ids = { ...baseIds, privatePlanId: null };
    expect(applyResolvedUrl('plans/:id/work', '/plans/1/work', ids)).toBe('/plans/1/work');
  });

  it('does not substring-replace master ids inside unrelated digits', () => {
    expect(applyResolvedUrl('crops/:id', '/crops/1', baseIds)).toBe('/crops/42');
    expect(applyResolvedUrl('crops/:id', '/crops/10', baseIds)).toBe('/crops/42');
  });

  it('resolves entry-schedule crop url with farm and crop ids', () => {
    expect(
      applyResolvedUrl('entry-schedule/crop/:cropId', '/entry-schedule/crop/1?farmId=1', baseIds)
    ).toBe('/entry-schedule/crop/15?farmId=7');
  });
});
