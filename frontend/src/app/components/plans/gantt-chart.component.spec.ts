import { ComponentFixture, TestBed } from '@angular/core/testing';
import { HttpClientTestingModule } from '@angular/common/http/testing';
import { TranslateModule } from '@ngx-translate/core';
import { vi, describe, it, expect, beforeEach } from 'vitest';

import { GanttChartComponent } from './gantt-chart.component';
import { PlanService } from '../../services/plans/plan.service';

describe('GanttChartComponent', () => {
  let component: GanttChartComponent;
  let fixture: ComponentFixture<GanttChartComponent>;
  let planService: PlanService;

  beforeEach(async () => {
    const planServiceMock = {
      adjustPlan: vi.fn(),
      getPlanData: vi.fn(),
      getPublicPlanData: vi.fn()
    };

    await TestBed.configureTestingModule({
      imports: [
        GanttChartComponent,
        HttpClientTestingModule,
        TranslateModule.forRoot()
      ],
      providers: [
        { provide: PlanService, useValue: planServiceMock }
      ]
    })
    .compileComponents();

    fixture = TestBed.createComponent(GanttChartComponent);
    component = fixture.componentInstance;
    planService = TestBed.inject(PlanService);
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  describe('adjustCultivation', () => {
    beforeEach(() => {
      // Mock data setup
      component.data = {
        data: {
          id: 7,
          planning_start_date: '2026-01-01',
          planning_end_date: '2026-12-31',
          fields: [{ id: 1, name: 'Field 1' }],
          cultivations: [{
            id: 14,
            field_id: 1,
            field_name: 'Field 1',
            start_date: '2026-01-01',
            completion_date: '2026-01-31'
          }]
        }
      } as any;

      component.fieldGroups = [{
        fieldName: 'Field 1',
        fieldId: 1,
        cultivations: []
      }];
    });

    it('should call private plan adjust endpoint when planType is private', () => {
      component.planType = 'private';

      planService.adjustPlan = vi.fn().mockReturnValue({
        subscribe: vi.fn()
      });

      component['adjustCultivation'](14, 'Field 1', 0, new Date('2026-09-15'));

      expect(planService.adjustPlan).toHaveBeenCalledWith(
        '/api/v1/plans/cultivation_plans/7/adjust',
        expect.any(Object)
      );
    });

    it('should call public plan adjust endpoint when planType is public', () => {
      component.planType = 'public';

      planService.adjustPlan = vi.fn().mockReturnValue({
        subscribe: vi.fn()
      });

      component['adjustCultivation'](14, 'Field 1', 0, new Date('2026-09-15'));

      expect(planService.adjustPlan).toHaveBeenCalledWith(
        '/api/v1/public_plans/cultivation_plans/7/adjust',
        expect.any(Object)
      );
    });
  });
});