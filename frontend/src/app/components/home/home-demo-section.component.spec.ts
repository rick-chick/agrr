import { Component, Input } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { HomeDemoSectionComponent } from './home-demo-section.component';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { buildLandingDemoPlanFixture } from '../../domain/plans/landing-demo-plan.fixture';
import { LANDING_DEMO_LABELS_FIXTURE } from '../../domain/plans/landing-demo-i18n.keys';
import { SyncLandingDemoPlanUseCase } from '../../usecase/plans/sync-landing-demo-plan.usecase';
import { HomeDemoSectionPresenter } from '../../adapters/plans/home-demo-section.presenter';

@Component({
  selector: 'app-plan-gantt-climate-shell',
  standalone: true,
  template: ''
})
class StubPlanGanttClimateShellComponent {
  @Input() data: CultivationPlanData | null = null;
  @Input() planType: 'private' | 'public' | 'demo' = 'demo';
}

describe('HomeDemoSectionComponent', () => {
  let fixture: ComponentFixture<HomeDemoSectionComponent>;
  let mockRouter: { navigate: ReturnType<typeof vi.fn> };
  let mockSyncUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: { setView: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    mockRouter = { navigate: vi.fn() };
    mockSyncUseCase = { execute: vi.fn() };
    mockPresenter = { setView: vi.fn() };

    await TestBed.configureTestingModule({
      imports: [HomeDemoSectionComponent, TranslateModule.forRoot()],
      providers: [
        { provide: Router, useValue: mockRouter },
        { provide: SyncLandingDemoPlanUseCase, useValue: mockSyncUseCase },
        { provide: HomeDemoSectionPresenter, useValue: mockPresenter }
      ]
    })
      .overrideComponent(HomeDemoSectionComponent, {
        set: { imports: [TranslateModule, StubPlanGanttClimateShellComponent], providers: [] }
      })
      .compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'ja',
      {
        home: {
          index: {
            demo: {
              hints_aria: '操作のヒント',
              hints: {
                drag: 'ドラッグで期間を調整',
                tap: 'クリックで気象・GDD',
                add: '作物を追加'
              },
              cta_create: '地域と作物を選んで計画を作る',
              fixture: {
                plan_name: 'デモ計画',
                farm_name: 'デモ農場',
                field_a: 'A',
                field_b: 'B',
                field_c: 'C',
                crop_tomato: 'トマト',
                crop_cucumber: 'キュウリ',
                crop_eggplant: 'ナス',
                crop_pepper: 'ピーマン',
                variety_pepper: 'vp',
                variety_eggplant: 've',
                stage_germination: 'sg',
                stage_growth: 'sgr',
                stage_harvest: 'sh',
                gdd_stage_growing: 'gg',
                gdd_stage_pre_harvest: 'gph'
              }
            }
          }
        }
      },
      true
    );
    translate.use('ja');

    mockSyncUseCase.execute.mockImplementation(({ labels }) => {
      fixture?.componentInstance.applyDemoPlanData(
        buildLandingDemoPlanFixture(labels ?? LANDING_DEMO_LABELS_FIXTURE)
      );
    });

    fixture = TestBed.createComponent(HomeDemoSectionComponent);
  });

  it('shows hints and gantt without preview chrome', () => {
    fixture.detectChanges();

    const root = fixture.nativeElement as HTMLElement;
    expect(root.querySelector('h2')).toBeNull();
    expect(root.querySelector('.home-demo-gantt__chrome')).toBeNull();
    expect(root.querySelector('.home-demo-section__disclaimer')).toBeNull();
    expect(root.querySelector('.home-demo-hints')).not.toBeNull();
    expect(root.querySelector('.home-demo-gantt')).not.toBeNull();
    expect(root.querySelector('app-plan-gantt-climate-shell')).not.toBeNull();
    expect(root.querySelector('button.btn-primary')?.textContent?.trim()).toBe(
      '地域と作物を選んで計画を作る'
    );
  });

  it('navigates to public plan creation', () => {
    fixture.detectChanges();

    fixture.nativeElement.querySelector('button.btn-primary')?.click();

    expect(mockRouter.navigate).toHaveBeenCalledWith(['/public-plans/new'] as const);
  });

  it('syncs localized demo plan when locale changes', () => {
    fixture.detectChanges();
    expect(mockSyncUseCase.execute).toHaveBeenCalledTimes(1);
    expect(mockPresenter.setView).toHaveBeenCalledWith(fixture.componentInstance);

    const translate = TestBed.inject(TranslateService);
    translate.use('en');

    expect(mockSyncUseCase.execute).toHaveBeenCalledTimes(2);
  });
});
