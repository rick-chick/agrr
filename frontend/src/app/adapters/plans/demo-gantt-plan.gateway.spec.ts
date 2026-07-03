import { describe, it, expect, beforeEach, vi } from 'vitest';
import { firstValueFrom } from 'rxjs';

import { DemoGanttPlanGateway } from './demo-gantt-plan.gateway';
import { DemoGanttPlanMemoryGateway } from './demo-gantt-plan-memory.gateway';
import { LANDING_DEMO_PLAN_ID } from '../../domain/plans/cultivation-plan-context-type';
import { LANDING_DEMO_LABELS_FIXTURE } from '../../domain/plans/landing-demo-i18n.keys';
import { ganttMutationCommandSuccess } from '../../domain/plans/gantt-plan-mutation';

describe('DemoGanttPlanGateway', () => {
  let demoStore: DemoGanttPlanMemoryGateway;
  let gateway: DemoGanttPlanGateway;

  beforeEach(() => {
    demoStore = new DemoGanttPlanMemoryGateway();
    demoStore.initialize(LANDING_DEMO_LABELS_FIXTURE);
    gateway = new DemoGanttPlanGateway(demoStore);
  });

  describe('syncLandingDemoPlan', () => {
    it('initializes demo store and returns localized plan without HTTP', async () => {
      const data = await firstValueFrom(gateway.syncLandingDemoPlan(LANDING_DEMO_LABELS_FIXTURE));

      expect(data.data.cultivations.length).toBeGreaterThan(0);
    });
  });

  describe('loadPlanData', () => {
    it('returns demo plan data without HTTP', async () => {
      const data = await firstValueFrom(gateway.loadPlanData('demo', LANDING_DEMO_PLAN_ID));
      expect(data?.data.cultivations.length).toBeGreaterThan(0);
    });

    it('returns null for non-demo planType', async () => {
      const result = await firstValueFrom(gateway.loadPlanData('private', 7));
      expect(result).toBeNull();
    });
  });

  describe('adjustCultivationMove', () => {
    it('delegates to demo store without HTTP', async () => {
      const spy = vi.spyOn(demoStore, 'adjustCultivationMove');

      const result = await firstValueFrom(
        gateway.adjustCultivationMove({
          planType: 'demo',
          planId: LANDING_DEMO_PLAN_ID,
          cultivationId: 501,
          toFieldId: 101,
          newStartDate: new Date('2026-05-01')
        })
      );

      expect(spy).toHaveBeenCalledWith({
        planId: LANDING_DEMO_PLAN_ID,
        cultivationId: 501,
        toFieldId: 101,
        newStartDate: new Date('2026-05-01')
      });
      expect(result).toEqual(ganttMutationCommandSuccess());
    });
  });
});
