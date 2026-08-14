import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { of } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { clearLearnProposalApplicationProgressCache } from '../../domain/plans/learn-proposal-application-progress';
import { PLAN_GATEWAY } from '../../usecase/plans/plan-gateway';
import { PlanLearnNavBadgeComponent } from './plan-learn-nav-badge.component';

describe('PlanLearnNavBadgeComponent', () => {
  let fixture: ComponentFixture<PlanLearnNavBadgeComponent>;

  beforeEach(async () => {
    clearLearnProposalApplicationProgressCache();
    await TestBed.configureTestingModule({
      imports: [PlanLearnNavBadgeComponent, TranslateModule.forRoot()]
    })
      .overrideComponent(PlanLearnNavBadgeComponent, {
        set: {
          providers: [
            {
              provide: PLAN_GATEWAY,
              useValue: {
                getPlanVsActualSummary: vi.fn().mockReturnValue(
                  of({
                    plan_id: 7,
                    action_required_items: [],
                    unrecorded_count: 0,
                    categories: [],
                    top_variance_items: [],
                    stage_gdd_calibration_proposals: [
                      {
                        crop_id: 1,
                        crop_name: 'Tomato',
                        stage_order: 1,
                        stage_name: 'Vegetative',
                        average_gdd_delta: 10,
                        recorded_item_count: 2
                      }
                    ],
                    blueprint_timing_adjustment_proposals: []
                  })
                ),
                getVarianceLearning: vi.fn().mockReturnValue(of(null))
              }
            }
          ]
        }
      })
      .compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.show.nav.learn_badge.proposals': '{{count}} unapplied proposals'
      },
      true
    );

    fixture = TestBed.createComponent(PlanLearnNavBadgeComponent);
    fixture.componentInstance.planId = 7;
  });

  it('renders proposal count badge after loading learn state', async () => {
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const badge = fixture.nativeElement.querySelector('.plan-context-nav__badge--count');
    expect(badge).not.toBeNull();
    expect(badge.textContent?.trim()).toBe('1');
    expect(badge.getAttribute('aria-label')).toBe('1 unapplied proposals');
  });
});
