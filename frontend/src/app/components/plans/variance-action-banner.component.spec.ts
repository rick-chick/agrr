import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import { VarianceActionBannerComponent } from './variance-action-banner.component';
import type { PlanVarianceActionItem } from '../../domain/plans/plan-vs-actual-summary';

const sampleItem: PlanVarianceActionItem = {
  item_id: 11,
  field_cultivation_id: 100,
  category: 'general',
  name: 'Weed control',
  scheduled_date: '2026-06-01',
  actual_date: '2026-06-08',
  delta_days: 7,
  gdd_trigger: 100,
  gdd_at_actual: 110,
  gdd_delta: 10,
  exceedance_kind: 'days'
};

describe('VarianceActionBannerComponent', () => {
  let fixture: ComponentFixture<VarianceActionBannerComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [VarianceActionBannerComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture = TestBed.createComponent(VarianceActionBannerComponent);
    fixture.componentRef.setInput('planId', 7);
    fixture.componentRef.setInput('items', [sampleItem]);
    fixture.detectChanges();
    await fixture.whenStable();
  });

  it('shows banner with learn review link when action items exist', () => {
    const el: HTMLElement = fixture.nativeElement;
    expect(el.querySelector('.variance-action-banner')).toBeTruthy();
    expect(el.textContent).toContain('1 task exceeded the variance threshold');
    expect(el.textContent).toContain('Review proposals on the Review tab');
    const link = el.querySelector('a.variance-action-banner__link') as HTMLAnchorElement;
    expect(link.getAttribute('href')).toContain('/plans/7/learn');
  });

  it('hides banner when items are empty', () => {
    fixture.componentRef.setInput('items', []);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('.variance-action-banner')).toBeNull();
  });
});
