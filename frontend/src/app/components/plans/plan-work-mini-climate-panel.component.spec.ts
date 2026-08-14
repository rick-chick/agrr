import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { of } from 'rxjs';
import { PlanWorkMiniClimatePanelComponent } from './plan-work-mini-climate-panel.component';
import { FIELD_CLIMATE_GATEWAY } from '../../usecase/plans/field-climate/field-climate.gateway';

describe('PlanWorkMiniClimatePanelComponent', () => {
  let fixture: ComponentFixture<PlanWorkMiniClimatePanelComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanWorkMiniClimatePanelComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        {
          provide: FIELD_CLIMATE_GATEWAY,
          useValue: {
            fetchFieldClimateData: vi.fn(() =>
              of({
                success: true,
                field_cultivation: {
                  id: 5,
                  field_name: 'A',
                  crop_name: 'Tomato',
                  start_date: '',
                  completion_date: ''
                },
                farm: { id: 1, name: 'Farm', latitude: 0, longitude: 0 },
                crop_requirements: { base_temperature: 10 },
                weather_data: [
                  {
                    date: '2026-06-15',
                    temperature_max: 28,
                    temperature_min: 18,
                    temperature_mean: 23
                  }
                ],
                gdd_data: [{ date: '2026-06-17', gdd: 8, cumulative_gdd: 145.5 }],
                stages: []
              })
            )
          }
        },
        { provide: ChangeDetectorRef, useValue: { markForCheck: vi.fn() } }
      ]
    }).compileComponents();

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

  it('loads climate data on init and renders cumulative GDD and workbench link', async () => {
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const panel = fixture.nativeElement.querySelector('[data-testid="work-row-mini-climate-panel"]');
    expect(panel).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('累積 GDD: 145.5');
    expect(fixture.nativeElement.textContent).toContain('28');
    const link = fixture.nativeElement.querySelector(
      '[data-testid="work-row-mini-climate-workbench-link"]'
    ) as HTMLAnchorElement;
    expect(link?.getAttribute('href')).toContain('/plans/7');
    expect(link?.getAttribute('href')).toContain('field_cultivation_id=5');
  });
});
