import { describe, expect, it } from 'vitest';
import {
  buildPlanWorkbenchDeepLinkQuery,
  resolveDeepLinkFieldCultivationId
} from './plan-workbench-deep-link';

describe('plan workbench deep link helpers', () => {
  it('builds field_cultivation_id query params for the workbench route', () => {
    expect(buildPlanWorkbenchDeepLinkQuery(42)).toEqual({ field_cultivation_id: 42 });
  });

  it('accepts cultivation ids that exist on the plan', () => {
    expect(resolveDeepLinkFieldCultivationId([{ id: 10 }, { id: 20 }], 20)).toBe(20);
  });

  it('rejects missing or unknown cultivation ids', () => {
    expect(resolveDeepLinkFieldCultivationId([{ id: 10 }], null)).toBeNull();
    expect(resolveDeepLinkFieldCultivationId([{ id: 10 }], 0)).toBeNull();
    expect(resolveDeepLinkFieldCultivationId([{ id: 10 }], 99)).toBeNull();
  });
});
