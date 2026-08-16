import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PlanPostSaveBannerComponent } from './plan-post-save-banner.component';

describe('PlanPostSaveBannerComponent', () => {
  let fixture: ComponentFixture<PlanPostSaveBannerComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanPostSaveBannerComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.show.post_save_banner.title': 'Plan saved',
        'plans.show.post_save_banner.message': 'What would you like to do next?',
        'plans.show.post_save_banner.hint': 'Review your task schedule or start recording work.',
        'plans.show.post_save_banner.task_schedule_link': 'Review task schedule',
        'plans.show.post_save_banner.work_link': 'Start work records',
        'plans.show.post_save_banner.dismiss': 'Dismiss'
      },
      true
    );

    fixture = TestBed.createComponent(PlanPostSaveBannerComponent);
    fixture.componentInstance.planId = 7;
  });

  it('renders nothing when not visible', () => {
    fixture.componentInstance.visible = false;
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-post-save-banner')).toBeNull();
  });

  it('renders CTAs and dismiss when visible', () => {
    fixture.componentInstance.visible = true;
    fixture.detectChanges();

    const links = fixture.nativeElement.querySelectorAll('.plan-post-save-banner__actions a');
    expect(links).toHaveLength(2);
    expect(links[0].getAttribute('href')).toBe('/plans/7/task_schedule');
    expect(links[1].getAttribute('href')).toBe('/plans/7/work');
    expect(fixture.nativeElement.textContent).toContain('What would you like to do next?');
  });

  it('emits dismiss when dismiss button is clicked', () => {
    fixture.componentInstance.visible = true;
    fixture.detectChanges();

    const dismissSpy = vi.fn();
    fixture.componentInstance.dismiss.subscribe(dismissSpy);
    fixture.nativeElement.querySelector('.plan-post-save-banner__dismiss').click();

    expect(dismissSpy).toHaveBeenCalled();
  });
});
