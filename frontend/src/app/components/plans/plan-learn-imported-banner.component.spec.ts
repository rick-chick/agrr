import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { PlanLearnImportedBannerComponent } from './plan-learn-imported-banner.component';

describe('PlanLearnImportedBannerComponent', () => {
  let fixture: ComponentFixture<PlanLearnImportedBannerComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanLearnImportedBannerComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      'plans.learn.imported_banner.message': '{{count}} imported items',
      'plans.learn.imported_banner.merged_proposals': '{{count}} merged proposals',
      'plans.learn.imported_banner.manual_hint': 'Review manually',
      'plans.learn.imported_banner.workbench_link': 'Open workbench'
    });
    translate.setDefaultLang('en');
    translate.use('en');

    fixture = TestBed.createComponent(PlanLearnImportedBannerComponent);
    fixture.componentInstance.planId = 7;
  });

  it('renders workbench link when action items are present', () => {
    fixture.componentInstance.items = [
      {
        item_id: 1,
        field_cultivation_id: 10,
        category: 'general',
        name: 'Weed control',
        scheduled_date: '2026-06-01',
        actual_date: '2026-06-08',
        delta_days: 7,
        gdd_trigger: 100,
        gdd_at_actual: 110,
        gdd_delta: 10,
        exceedance_kind: 'days'
      }
    ];
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector(
      'a.plan-learn-imported-banner__link'
    ) as HTMLAnchorElement;
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toContain('/plans/7');
    expect(link.getAttribute('href')).toContain('field_cultivation_id=10');
  });

  it('hides banner when no action items and no merged proposals', () => {
    fixture.componentInstance.items = [];
    fixture.componentInstance.mergedProposalCount = 0;
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('.plan-learn-imported-banner')).toBeNull();
  });

  it('shows merged proposal count when proposals were imported', () => {
    fixture.componentInstance.items = [];
    fixture.componentInstance.mergedProposalCount = 3;
    fixture.detectChanges();

    const banner = fixture.nativeElement.querySelector('.plan-learn-imported-banner');
    expect(banner).toBeTruthy();
    expect(banner.textContent).toContain('3');
  });
});
