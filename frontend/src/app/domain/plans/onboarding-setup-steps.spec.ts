import { describe, expect, it } from 'vitest';
import { buildOnboardingSteps } from './onboarding-setup-steps';
import { buildPlanCreateReadiness } from './plan-create-readiness';

describe('buildOnboardingSteps', () => {
  it('marks farm step incomplete when no farms exist', () => {
    const steps = buildOnboardingSteps([], null);
    expect(steps[0]).toMatchObject({ id: 'farm', ready: false, routerLink: '/farms/new' });
  });

  it('links to farm detail for fields and weather when a farm exists', () => {
    const farms = [{ id: 5, name: 'Farm', fieldCount: 2, totalArea: 100, hasValidFields: true }];
    const readiness = buildPlanCreateReadiness({
      farmId: 5,
      fieldCount: 2,
      hasValidFields: true,
      weatherStatus: 'completed',
      crops: [],
      cropBlueprints: {}
    });
    const steps = buildOnboardingSteps(farms, readiness);

    expect(steps[0].ready).toBe(true);
    expect(steps[1].routerLink).toEqual(['/farms', 5]);
    expect(steps[1].ready).toBe(true);
    expect(steps[3].ready).toBe(true);
    expect(steps[2].ready).toBe(false);
    expect(steps[2].routerLink).toBe('/crops/new');
  });
});
