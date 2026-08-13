import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import { VarianceActionProposalCardsComponent } from './variance-action-proposal-cards.component';
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

describe('VarianceActionProposalCardsComponent', () => {
  let fixture: ComponentFixture<VarianceActionProposalCardsComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [VarianceActionProposalCardsComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture = TestBed.createComponent(VarianceActionProposalCardsComponent);
    fixture.componentRef.setInput('planId', 7);
    fixture.componentRef.setInput('items', [sampleItem]);
    fixture.detectChanges();
    await fixture.whenStable();
  });

  it('renders proposal cards with manual action hint, workbench link, and status badge', () => {
    const el: HTMLElement = fixture.nativeElement;
    expect(el.textContent).toContain('Schedule variance needs your review');
    expect(el.textContent).toContain('Adjust or re-optimize only after you confirm');
    expect(el.textContent).toContain('Weed control');
    expect(el.textContent).toContain('Not applied');
    expect(el.querySelector('.variance-action-proposals__status')).toBeTruthy();
    const link = el.querySelector('a.variance-action-proposals__cta') as HTMLAnchorElement;
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toContain('/plans/7');
    expect(link.getAttribute('href')).toContain('field_cultivation_id=100');
  });

  it('renders nothing when items are empty', () => {
    fixture.componentRef.setInput('items', []);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('.variance-action-proposals')).toBeNull();
  });
});
