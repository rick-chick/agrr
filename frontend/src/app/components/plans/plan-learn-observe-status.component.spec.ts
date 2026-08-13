import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import { PlanLearnObserveStatusComponent } from './plan-learn-observe-status.component';

describe('PlanLearnObserveStatusComponent', () => {
  let fixture: ComponentFixture<PlanLearnObserveStatusComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanLearnObserveStatusComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture = TestBed.createComponent(PlanLearnObserveStatusComponent);
    fixture.componentInstance.planId = 7;
  });

  it('renders nothing while variance summary is loading', () => {
    fixture.componentInstance.varianceLoading = true;
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-learn-observe-status')).toBeNull();
  });

  it('shows unrecorded count and work CTA when unrecorded_count is positive', () => {
    fixture.componentInstance.varianceLoading = false;
    fixture.componentInstance.varianceError = null;
    fixture.componentInstance.unrecordedCount = 4;
    fixture.detectChanges();

    const root = fixture.nativeElement.querySelector('.plan-learn-observe-status--unrecorded');
    expect(root).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('4 tasks still need work records');
    const link = fixture.nativeElement.querySelector(
      'a.plan-learn-observe-status__cta'
    ) as HTMLAnchorElement;
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toContain('/plans/7/work');
  });

  it('shows observe phase complete when variance is loaded and unrecorded_count is zero', () => {
    fixture.componentInstance.varianceLoading = false;
    fixture.componentInstance.varianceError = null;
    fixture.componentInstance.unrecordedCount = 0;
    fixture.detectChanges();

    const root = fixture.nativeElement.querySelector('.plan-learn-observe-status--complete');
    expect(root).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Observation phase complete');
    expect(fixture.nativeElement.querySelector('a.plan-learn-observe-status__cta')).toBeNull();
  });
});
