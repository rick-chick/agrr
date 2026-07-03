import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { describe, it, expect, beforeEach } from 'vitest';
import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';
import { PlanGanttClimateShellComponent } from './plan-gantt-climate-shell.component';
import { GANTT_CHART_API_PROVIDERS } from '../../usecase/plans/gantt-chart.providers';
import { PLAN_FIELD_CLIMATE_API_PROVIDERS } from '../../usecase/plans/plan-field-climate.providers';
import type { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';

@Component({
  selector: 'app-gantt-chart',
  template: '',
  standalone: true
})
class StubGanttChartComponent {
  @Input({ required: true }) data!: CultivationPlanData;
  @Input() planType: 'private' | 'public' | 'demo' = 'private';
}

@Component({
  selector: 'app-plan-field-climate',
  template: '',
  standalone: true
})
class StubPlanFieldClimateComponent {
  @Input({ required: true }) fieldCultivationId!: number;
  @Input() planType: 'private' | 'public' | 'demo' = 'private';
  @Input() displayStartDate: string | null = null;
  @Input() displayEndDate: string | null = null;
}

const CLIMATE_PLACEHOLDER_KEY = 'plans.detail.select_cultivation_hint';

function nestedValue(obj: Record<string, unknown>, path: string): string {
  const value = path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as Record<string, unknown>)[key];
  }, obj);
  if (typeof value !== 'string') {
    throw new Error(`missing string at ${path}`);
  }
  return value;
}

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

  describe('climate placeholder i18n (public-plans/results shared shell)', () => {
    let fixture: ComponentFixture<PlanGanttClimateShellComponent>;
    let translate: TranslateService;

    beforeEach(async () => {
      await TestBed.configureTestingModule({
        imports: [PlanGanttClimateShellComponent, TranslateModule.forRoot()],
        providers: [...GANTT_CHART_API_PROVIDERS, ...PLAN_FIELD_CLIMATE_API_PROVIDERS]
      })
        .overrideComponent(PlanGanttClimateShellComponent, {
          set: {
            imports: [
              CommonModule,
              StubGanttChartComponent,
              StubPlanFieldClimateComponent,
              TranslateModule
            ],
            providers: []
          }
        })
        .compileComponents();

      translate = TestBed.inject(TranslateService);
      translate.setTranslation('ja', ja as TranslationObject, true);
      translate.setTranslation('en', en as TranslationObject, true);
      translate.setTranslation('in', inLocale as TranslationObject, true);

      fixture = TestBed.createComponent(PlanGanttClimateShellComponent);
      fixture.componentInstance.data = sampleData;
      fixture.componentInstance.planType = 'public';
    });

    it.each([
      ['ja', ja],
      ['en', en],
      ['in', inLocale]
    ] as const)('renders localized placeholder for %s locale', async (localeId, bundle) => {
      translate.use(localeId);
      fixture.detectChanges();
      await fixture.whenStable();

      const placeholder = fixture.nativeElement.querySelector('.plan-detail__climate-placeholder');
      const expected = nestedValue(bundle as Record<string, unknown>, CLIMATE_PLACEHOLDER_KEY);
      const english = nestedValue(en as Record<string, unknown>, CLIMATE_PLACEHOLDER_KEY);

      expect(placeholder?.textContent?.trim()).toBe(expected);
      if (localeId !== 'en') {
        expect(placeholder?.textContent?.trim()).not.toBe(english);
      }
    });
  });
});
