import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PlanPostSaveOnboardingBannerComponent } from './plan-post-save-onboarding-banner.component';

describe('PlanPostSaveOnboardingBannerComponent', () => {
  let fixture: ComponentFixture<PlanPostSaveOnboardingBannerComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanPostSaveOnboardingBannerComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      plans: {
        show: {
          post_save_onboarding: {
            message: 'Your plan is saved',
            hint: 'Next steps',
            task_schedule_link: 'Check task schedule',
            work_link: 'Start work records',
            dismiss: 'Dismiss'
          }
        }
      }
    });
    translate.setDefaultLang('en');
    translate.use('en');

    fixture = TestBed.createComponent(PlanPostSaveOnboardingBannerComponent);
    fixture.componentInstance.planId = 5;
  });

  it('renders task schedule and work record CTAs', () => {
    fixture.detectChanges();

    const taskScheduleLink = fixture.nativeElement.querySelector(
      'a[href*="/task_schedule"]'
    ) as HTMLAnchorElement;
    const workLink = fixture.nativeElement.querySelector(
      'a[href*="/work"]'
    ) as HTMLAnchorElement;

    expect(taskScheduleLink).toBeTruthy();
    expect(taskScheduleLink.getAttribute('href')).toContain('/plans/5/task_schedule');
    expect(workLink).toBeTruthy();
    expect(workLink.getAttribute('href')).toContain('/plans/5/work');
  });

  it('emits dismiss when dismiss button is clicked', () => {
    fixture.detectChanges();
    const dismissSpy = vi.fn();
    fixture.componentInstance.dismiss.subscribe(dismissSpy);

    const dismissButton = fixture.nativeElement.querySelector(
      '.plan-post-save-onboarding-banner__dismiss'
    ) as HTMLButtonElement;
    dismissButton.click();

    expect(dismissSpy).toHaveBeenCalled();
  });
});
