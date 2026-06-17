import { describe, expect, it } from 'vitest';
import { applyResolvedUrl, type ResolvedCaptureIds } from '../../../e2e/shared/apply-resolved-url';

describe('applyResolvedUrl (plans work routes)', () => {
  const ids: ResolvedCaptureIds = {
    masters: {},
    privatePlanId: 42,
    publicPlanId: null,
    farmId: null,
    cropId: null
  };

  it('resolves plans/:id/work to baseline private plan id', () => {
    const url = applyResolvedUrl('plans/:id/work', '/plans/1/work', ids);
    expect(url).toBe('/plans/42/work');
  });

  it('resolves plans/:id/work_records to baseline private plan id', () => {
    const url = applyResolvedUrl('plans/:id/work_records', '/plans/1/work_records', ids);
    expect(url).toBe('/plans/42/work_records');
  });

  it('leaves work url unchanged when privatePlanId is missing', () => {
    const missing: ResolvedCaptureIds = { ...ids, privatePlanId: null };
    const url = applyResolvedUrl('plans/:id/work_records', '/plans/1/work_records', missing);
    expect(url).toBe('/plans/1/work_records');
  });
});
