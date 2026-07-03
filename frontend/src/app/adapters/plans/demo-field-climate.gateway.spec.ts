import { firstValueFrom } from 'rxjs';
import { describe, it, expect, beforeEach } from 'vitest';
import { DemoFieldClimateGateway } from './demo-field-climate.gateway';
import { DemoGanttPlanMemoryGateway } from './demo-gantt-plan-memory.gateway';
import { LANDING_DEMO_LABELS_FIXTURE } from '../../domain/plans/landing-demo-i18n.keys';

describe('DemoFieldClimateGateway', () => {
  let demoStore: DemoGanttPlanMemoryGateway;
  let gateway: DemoFieldClimateGateway;

  beforeEach(() => {
    demoStore = new DemoGanttPlanMemoryGateway();
    demoStore.initialize(LANDING_DEMO_LABELS_FIXTURE);
    gateway = new DemoFieldClimateGateway(demoStore);
  });

  it('returns bundled demo climate for cultivation 501 tomato without HTTP', async () => {
    const result = await firstValueFrom(
      gateway.fetchFieldClimateData({
        fieldCultivationId: 501,
        planType: 'demo'
      })
    );
    expect(result.field_cultivation.crop_name).toBe('Tomato');
  });

  it('throws when demo climate is not found', async () => {
    await expect(
      firstValueFrom(
        gateway.fetchFieldClimateData({
          fieldCultivationId: 99999,
          planType: 'demo'
        })
      )
    ).rejects.toThrow('demo climate not found');
  });

  it('rejects non-demo planType with a clear message', async () => {
    await expect(
      firstValueFrom(
        gateway.fetchFieldClimateData({
          fieldCultivationId: 501,
          planType: 'private'
        })
      )
    ).rejects.toThrow('demo plan type is not supported by demo climate gateway');
  });
});
