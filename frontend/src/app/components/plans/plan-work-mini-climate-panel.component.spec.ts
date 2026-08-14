import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PlanWorkMiniClimatePanelComponent } from './plan-work-mini-climate-panel.component';
import { PlanWorkMiniClimatePanelPresenter } from '../../adapters/plans/plan-work-mini-climate-panel.presenter';
import { PreviewWorkRowMiniClimateUseCase } from '../../usecase/plans/preview-work-row-mini-climate/preview-work-row-mini-climate.usecase';
import { PREVIEW_WORK_ROW_MINI_CLIMATE_PROVIDERS } from '../../usecase/plans/preview-work-row-mini-climate/preview-work-row-mini-climate.providers';

describe('PlanWorkMiniClimatePanelComponent', () => {
  let fixture: ComponentFixture<PlanWorkMiniClimatePanelComponent>;
  let translate: TranslateService;
  let previewUseCase: { execute: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    previewUseCase = { execute: vi.fn() };

    await TestBed.configureTestingModule({
      imports: [PlanWorkMiniClimatePanelComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        ...PREVIEW_WORK_ROW_MINI_CLIMATE_PROVIDERS.filter(
          (provider) =>
            typeof provider !== 'object' ||
            !('provide' in provider) ||
            provider.provide !== PreviewWorkRowMiniClimateUseCase
        ),
        { provide: PreviewWorkRowMiniClimateUseCase, useValue: previewUseCase },
        { provide: ChangeDetectorRef, useValue: { markForCheck: vi.fn() } }
      ]
    })
      .overrideComponent(PlanWorkMiniClimatePanelComponent, {
        set: {
          providers: [
            ...PREVIEW_WORK_ROW_MINI_CLIMATE_PROVIDERS.filter(
              (provider) =>
                typeof provider !== 'object' ||
                !('provide' in provider) ||
                provider.provide !== PreviewWorkRowMiniClimateUseCase
            ),
            { provide: PreviewWorkRowMiniClimateUseCase, useValue: previewUseCase }
          ]
        }
      })
      .compileComponents();

    translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'ja',
      {
        'plans.work.mini_climate.title': 'ミニ気候パネル',
        'plans.work.mini_climate.loading': '気候データを読み込み中…',
        'plans.work.mini_climate.unavailable': '気候データを取得できませんでした',
        'plans.work.mini_climate.cumulative_gdd': '累積 GDD: {{value}}',
        'plans.work.mini_climate.daily_weather':
          '最高 {{max}}℃ / 最低 {{min}}℃ / 平均 {{mean}}℃',
        'plans.work.mini_climate.workbench_link': 'ワークベンチの気候パネルを開く'
      },
      true
    );
    translate.use('ja');

    fixture = TestBed.createComponent(PlanWorkMiniClimatePanelComponent);
    fixture.componentRef.setInput('planId', 7);
    fixture.componentRef.setInput('fieldCultivationId', 5);
  });

  it('loads climate data on init and renders cumulative GDD and workbench link', () => {
    previewUseCase.execute.mockImplementation(() => {
      const panelPresenter = fixture.debugElement.injector.get(PlanWorkMiniClimatePanelPresenter);
      panelPresenter.presentMiniClimate({
        cumulativeGdd: 145.5,
        dailyWeather: [
          {
            date: '2026-06-15',
            temperatureMax: 28,
            temperatureMin: 18,
            temperatureMean: 23
          }
        ],
        startDate: '2026-06-11',
        endDate: '2026-06-17',
        loading: false
      });
    });

    fixture.detectChanges();

    const panel = fixture.nativeElement.querySelector('[data-testid="work-row-mini-climate-panel"]');
    expect(panel).toBeTruthy();
    expect(previewUseCase.execute).toHaveBeenCalledWith(
      expect.objectContaining({ fieldCultivationId: 5 })
    );
    expect(fixture.nativeElement.textContent).toContain('累積 GDD: 145.5');
    expect(fixture.nativeElement.textContent).toContain('28');
    const link = fixture.nativeElement.querySelector(
      '[data-testid="work-row-mini-climate-workbench-link"]'
    ) as HTMLAnchorElement;
    expect(link?.getAttribute('href')).toContain('/plans/7');
    expect(link?.getAttribute('href')).toContain('field_cultivation_id=5');
  });
});
