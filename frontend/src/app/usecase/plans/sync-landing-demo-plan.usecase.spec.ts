import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { LANDING_DEMO_LABELS_FIXTURE } from '../../domain/plans/landing-demo-i18n.keys';
import { GanttPlanGateway } from './gantt-plan-gateway';
import { SyncLandingDemoPlanOutputPort } from './sync-landing-demo-plan.output-port';
import { SyncLandingDemoPlanUseCase } from './sync-landing-demo-plan.usecase';

describe('SyncLandingDemoPlanUseCase', () => {
  const planData = (): CultivationPlanData =>
    ({
      data: {
        id: 1,
        planning_start_date: '2026-01-01',
        planning_end_date: '2026-12-31',
        fields: [{ id: 1, name: 'Field 1' }],
        cultivations: []
      }
    }) as CultivationPlanData;

  it('syncs localized demo plan via gateway and forwards to output port', () => {
    const data = planData();
    const gateway: Pick<GanttPlanGateway, 'syncLandingDemoPlan'> = {
      syncLandingDemoPlan: vi.fn(() => of(data))
    };
    const outputPort: SyncLandingDemoPlanOutputPort = {
      onDemoPlanLoaded: vi.fn(),
      onLoadError: vi.fn()
    };

    const useCase = new SyncLandingDemoPlanUseCase(outputPort, gateway as GanttPlanGateway);
    useCase.execute({ labels: LANDING_DEMO_LABELS_FIXTURE });

    expect(gateway.syncLandingDemoPlan).toHaveBeenCalledWith(LANDING_DEMO_LABELS_FIXTURE);
    expect(outputPort.onDemoPlanLoaded).toHaveBeenCalledWith({ data });
    expect(outputPort.onLoadError).not.toHaveBeenCalled();
  });

  it('forwards gateway errors to output port', () => {
    const gateway: Pick<GanttPlanGateway, 'syncLandingDemoPlan'> = {
      syncLandingDemoPlan: vi.fn(() => throwError(() => new Error('sync failed')))
    };
    const outputPort: SyncLandingDemoPlanOutputPort = {
      onDemoPlanLoaded: vi.fn(),
      onLoadError: vi.fn()
    };

    const useCase = new SyncLandingDemoPlanUseCase(outputPort, gateway as GanttPlanGateway);
    useCase.execute({ labels: LANDING_DEMO_LABELS_FIXTURE });

    expect(outputPort.onLoadError).toHaveBeenCalledWith({
      message: 'common.api_error.generic'
    });
    expect(outputPort.onDemoPlanLoaded).not.toHaveBeenCalled();
  });
});
