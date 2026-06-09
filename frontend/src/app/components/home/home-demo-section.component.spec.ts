import { Component, Input } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { HomeDemoSectionComponent } from './home-demo-section.component';
import { DemoGanttPlanStore } from '../../services/plans/demo-gantt-plan-store.service';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { buildLandingDemoPlanFixture } from '../../domain/plans/landing-demo-plan.fixture';
import { LANDING_DEMO_LABELS_FIXTURE } from '../../domain/plans/landing-demo-i18n.keys';

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
  let mockDemoStore: { syncHomeDemoViewState: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    mockRouter = { navigate: vi.fn() };
    mockDemoStore = { syncHomeDemoViewState: vi.fn() };

    await TestBed.configureTestingModule({
      imports: [HomeDemoSectionComponent, TranslateModule.forRoot()],
      providers: [
        { provide: Router, useValue: mockRouter },
        { provide: DemoGanttPlanStore, useValue: mockDemoStore }
      ]
    })
      .overrideComponent(HomeDemoSectionComponent, {
        set: { imports: [TranslateModule, StubPlanGanttClimateShellComponent] }
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
              cta_create: '地域と作物を選んで計画を作る'
            }
          }
        }
      },
      true
    );
    translate.use('ja');

    mockDemoStore.syncHomeDemoViewState.mockReturnValue({
      planData: buildLandingDemoPlanFixture(LANDING_DEMO_LABELS_FIXTURE)
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
    expect(root.querySelector('button.primary-button')?.textContent?.trim()).toBe(
      '地域と作物を選んで計画を作る'
    );
  });

  it('navigates to public plan creation', () => {
    fixture.detectChanges();

    fixture.nativeElement.querySelector('button.primary-button')?.click();

    expect(mockRouter.navigate).toHaveBeenCalledWith(['/public-plans/new'] as const);
  });
});
