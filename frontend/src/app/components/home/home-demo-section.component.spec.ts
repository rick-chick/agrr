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
              section: {
                title: '{{schedule}}{{separator}}{{preview}}',
                schedule: '作付',
                preview: 'プレビュー',
                separator: ' / ',
                preview_badge: 'PREVIEW'
              },
              hints_aria: 'ヒント',
              hint_drag: 'ドラッグ',
              disclaimer: 'デモです',
              cta_create: '作成'
            }
          }
        }
      },
      true
    );
    translate.use('ja');

    mockDemoStore.syncHomeDemoViewState.mockReturnValue({
      planData: buildLandingDemoPlanFixture(LANDING_DEMO_LABELS_FIXTURE),
      titleParams: { schedule: '作付', preview: 'プレビュー', separator: ' / ' }
    });
    fixture = TestBed.createComponent(HomeDemoSectionComponent);
  });

  it('reserves gantt layout space on first paint', () => {
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('.home-demo-gantt-wrap')).not.toBeNull();
    expect(fixture.nativeElement.querySelector('app-plan-gantt-climate-shell')).not.toBeNull();
  });

  it('navigates to public plan creation', () => {
    fixture.detectChanges();

    fixture.nativeElement.querySelector('button.primary-button')?.click();

    expect(mockRouter.navigate).toHaveBeenCalledWith(['/public-plans/new'] as const);
  });
});
