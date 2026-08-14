import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { PlanLearnObservePhaseStatusComponent } from './plan-learn-observe-phase-status.component';

describe('PlanLearnObservePhaseStatusComponent', () => {
  let fixture: ComponentFixture<PlanLearnObservePhaseStatusComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanLearnObservePhaseStatusComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.learn.observe_phase.unrecorded_message': '{{count}} tasks are not recorded yet.',
        'plans.learn.observe_phase.unrecorded_cta': 'Record work',
        'plans.learn.observe_phase.complete_message': 'Observation phase complete — all scheduled tasks are recorded.'
      },
      true
    );

    fixture = TestBed.createComponent(PlanLearnObservePhaseStatusComponent);
    fixture.componentInstance.planId = 7;
  });

  it('renders nothing while status is null', () => {
    fixture.componentInstance.status = null;
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-learn-observe-phase')).toBeNull();
  });

  it('shows unrecorded count and work CTA when status is unrecorded', () => {
    fixture.componentInstance.status = 'unrecorded';
    fixture.componentInstance.unrecordedCount = 4;
    fixture.detectChanges();

    const banner = fixture.nativeElement.querySelector('.plan-learn-observe-phase');
    expect(banner).toBeTruthy();
    expect(banner.textContent).toContain('4 tasks are not recorded yet.');

    const link = fixture.nativeElement.querySelector(
      'a.plan-learn-observe-phase__cta'
    ) as HTMLAnchorElement;
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toBe('/plans/7/work');
    expect(link.textContent).toContain('Record work');
  });

  it('includes task_schedule_item_id query param when focusItemId is set', () => {
    fixture.componentInstance.status = 'unrecorded';
    fixture.componentInstance.unrecordedCount = 2;
    fixture.componentInstance.focusItemId = 55;
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector(
      'a.plan-learn-observe-phase__cta'
    ) as HTMLAnchorElement;
    expect(link.getAttribute('href')).toContain('/plans/7/work');
    expect(link.getAttribute('href')).toContain('task_schedule_item_id=55');
  });

  it('shows completion message when status is complete', () => {
    fixture.componentInstance.status = 'complete';
    fixture.detectChanges();

    const banner = fixture.nativeElement.querySelector('.plan-learn-observe-phase');
    expect(banner).toBeTruthy();
    expect(banner.textContent).toContain('Observation phase complete');
    expect(fixture.nativeElement.querySelector('a.plan-learn-observe-phase__cta')).toBeNull();
  });
});
