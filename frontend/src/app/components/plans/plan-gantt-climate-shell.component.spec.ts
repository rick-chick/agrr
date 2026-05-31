import { describe, it, expect, beforeEach } from 'vitest';
import { PlanGanttClimateShellComponent } from './plan-gantt-climate-shell.component';
import type { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';

const sampleData = { success: true } as CultivationPlanData;

describe('PlanGanttClimateShellComponent', () => {
  let component: PlanGanttClimateShellComponent;

  beforeEach(() => {
    component = new PlanGanttClimateShellComponent();
    component.data = sampleData;
    component.planType = 'private';
  });

  describe('climate panel interactions', () => {
    it('opens the climate panel for a new cultivation selection', () => {
      component.handleCultivationSelection({ cultivationId: 5, planType: 'private' });

      expect(component.selectedCultivationId).toBe(5);
      expect(component.selectedPlanType).toBe('private');
    });

    it('closes the climate panel when the same cultivation is selected again', () => {
      component.selectedCultivationId = 5;
      component.selectedPlanType = 'private';

      component.handleCultivationSelection({ cultivationId: 5, planType: 'private' });

      expect(component.selectedCultivationId).toBeNull();
      expect(component.selectedPlanType).toBe('private');
    });

    it('resets selection via closeClimatePanel to the shell plan type', () => {
      component.selectedCultivationId = 8;
      component.selectedPlanType = 'public';

      component.closeClimatePanel();

      expect(component.selectedCultivationId).toBeNull();
      expect(component.selectedPlanType).toBe('private');
    });
  });

  it('maps gantt visible range to ISO date strings', () => {
    component.handleVisibleRangeUpdate({
      startDate: new Date('2026-04-01T00:00:00'),
      endDate: new Date('2026-06-30T00:00:00'),
      label: 'Q2'
    });

    expect(component.visibleRangeStartDate).toBe('2026-04-01');
    expect(component.visibleRangeEndDate).toBe('2026-06-30');
  });
});
