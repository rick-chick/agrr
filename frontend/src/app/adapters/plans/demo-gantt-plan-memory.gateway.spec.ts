import { describe, it, expect, beforeEach } from 'vitest';
import { firstValueFrom } from 'rxjs';
import { DemoGanttPlanMemoryGateway } from './demo-gantt-plan-memory.gateway';
import { LANDING_DEMO_PLAN_ID } from '../../domain/plans/cultivation-plan-context-type';
import { LANDING_DEMO_LABELS_FIXTURE } from '../../domain/plans/landing-demo-i18n.keys';
import { ganttMutationCommandSuccess } from '../../domain/plans/gantt-plan-mutation';

describe('DemoGanttPlanMemoryGateway', () => {
  let gateway: DemoGanttPlanMemoryGateway;

  beforeEach(() => {
    gateway = new DemoGanttPlanMemoryGateway();
    gateway.initialize(LANDING_DEMO_LABELS_FIXTURE);
  });

  it('returns a deep clone of the current plan snapshot', () => {
    const a = gateway.getSnapshot();
    const b = gateway.getSnapshot();
    expect(a).not.toBe(b);
    expect(a.data.cultivations).toHaveLength(3);
  });

  it('adjustCultivationMove updates state and returns command success', async () => {
    const before = gateway.getSnapshot().data.cultivations.find((c) => c.id === 501)!;
    const result = await firstValueFrom(
      gateway.adjustCultivationMove({
        planId: LANDING_DEMO_PLAN_ID,
        cultivationId: 501,
        toFieldId: 101,
        newStartDate: new Date('2026-05-01')
      })
    );
    expect(result).toEqual(ganttMutationCommandSuccess());
    const updated = gateway.getSnapshot().data.cultivations.find((c) => c.id === 501)!;
    expect(updated.start_date).toBe('2026-05-01');
    expect(updated.start_date).not.toBe(before.start_date);
  });

  it('addCrop appends a cultivation on the first field', async () => {
    const result = await firstValueFrom(
      gateway.addCrop(LANDING_DEMO_PLAN_ID, {
        crop_id: 204,
        display_start_date: '2026-03-15',
        display_end_date: '2026-12-31'
      })
    );
    expect(result).toEqual(ganttMutationCommandSuccess());
    expect(gateway.getSnapshot().data.cultivations.length).toBe(4);
    expect(gateway.getSnapshot().data.cultivations.some((c) => c.crop_name === 'Bell pepper')).toBe(
      true
    );
  });

  it('removeCultivation removes the bar', async () => {
    const result = await firstValueFrom(gateway.removeCultivation(LANDING_DEMO_PLAN_ID, 502));
    expect(result).toEqual(ganttMutationCommandSuccess());
    expect(gateway.getSnapshot().data.cultivations.some((c) => c.id === 502)).toBe(false);
  });
});
