import { describe, it, expect, beforeEach } from 'vitest';
import { firstValueFrom } from 'rxjs';
import { DemoGanttPlanStore } from './demo-gantt-plan-store.service';
import { LANDING_DEMO_PLAN_ID } from '../../domain/plans/cultivation-plan-context-type';
import { LANDING_DEMO_LABELS_FIXTURE } from '../../domain/plans/landing-demo-i18n.keys';

describe('DemoGanttPlanStore', () => {
  let store: DemoGanttPlanStore;

  beforeEach(() => {
    store = new DemoGanttPlanStore();
    store.initialize(LANDING_DEMO_LABELS_FIXTURE);
  });

  it('returns a deep clone of the current plan snapshot', () => {
    const a = store.getSnapshot();
    const b = store.getSnapshot();
    expect(a).not.toBe(b);
    expect(a.data.cultivations).toHaveLength(3);
  });

  it('adjustCultivationMove shifts dates without changing cultivation count', async () => {
    const before = store.getSnapshot().data.cultivations.find((c) => c.id === 501)!;
    const outcome = await firstValueFrom(
      store.adjustCultivationMove({
        planId: LANDING_DEMO_PLAN_ID,
        cultivationId: 501,
        toFieldId: 101,
        newStartDate: new Date('2026-05-01')
      })
    );
    expect(outcome.status).toBe('success');
    if (outcome.status !== 'success') return;
    const updated = outcome.data.data.cultivations.find((c) => c.id === 501)!;
    expect(updated.start_date).toBe('2026-05-01');
    expect(updated.start_date).not.toBe(before.start_date);
  });

  it('addCrop appends a cultivation on the first field', async () => {
    const outcome = await firstValueFrom(
      store.addCrop(LANDING_DEMO_PLAN_ID, {
        crop_id: 204,
        display_start_date: '2026-03-15',
        display_end_date: '2026-12-31'
      })
    );
    expect(outcome.status).toBe('success');
    if (outcome.status !== 'success') return;
    expect(outcome.data.data.cultivations.length).toBe(4);
    expect(outcome.data.data.cultivations.some((c) => c.crop_name === 'Bell pepper')).toBe(true);
  });

  it('removeCultivation removes the bar', async () => {
    const outcome = await firstValueFrom(store.removeCultivation(LANDING_DEMO_PLAN_ID, 502));
    expect(outcome.status).toBe('success');
    if (outcome.status !== 'success') return;
    expect(outcome.data.data.cultivations.some((c) => c.id === 502)).toBe(false);
  });

  it('resetToInitial restores the bundled fixture', async () => {
    await firstValueFrom(store.removeCultivation(LANDING_DEMO_PLAN_ID, 501));
    store.resetToInitial();
    expect(store.getSnapshot().data.cultivations).toHaveLength(3);
  });

  it('syncFromTranslate rebuilds labels and returns a snapshot', () => {
    const snapshot = store.syncFromTranslate({
      instant: (key: string) => `localized:${key}`
    });
    expect(snapshot.data.plan_name).toBe('localized:home.index.demo.fixture.plan_name');
    expect(snapshot.data.cultivations).toHaveLength(3);
  });

  it('syncHomeDemoViewState returns plan data and title params together', () => {
    const view = store.syncHomeDemoViewState({
      instant: (key: string) => `localized:${key}`
    });
    expect(view.planData.data.cultivations).toHaveLength(3);
    expect(view.titleParams.schedule).toBe('localized:home.index.demo.schedule');
    expect(view.titleParams.preview).toBe('localized:home.index.demo.preview');
  });
});
