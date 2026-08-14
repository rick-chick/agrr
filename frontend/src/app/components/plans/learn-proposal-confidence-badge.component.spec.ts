import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { LearnProposalConfidenceBadgeComponent } from './learn-proposal-confidence-badge.component';

describe('LearnProposalConfidenceBadgeComponent', () => {
  let fixture: ComponentFixture<LearnProposalConfidenceBadgeComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [LearnProposalConfidenceBadgeComponent, TranslateModule.forRoot()]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.learn.proposal_confidence.high': 'High confidence',
        'plans.learn.proposal_confidence.medium': 'Medium confidence',
        'plans.learn.proposal_confidence.low': 'Low confidence'
      },
      true
    );

    fixture = TestBed.createComponent(LearnProposalConfidenceBadgeComponent);
  });

  it('renders low confidence label with modifier class', () => {
    fixture.componentInstance.confidence = 'low';
    fixture.detectChanges();

    const badge = fixture.nativeElement.querySelector('.learn-proposal-confidence');
    expect(badge).toBeTruthy();
    expect(badge.classList.contains('learn-proposal-confidence--low')).toBe(true);
    expect(badge.textContent).toContain('Low confidence');
  });

  it('renders medium confidence label', () => {
    fixture.componentInstance.confidence = 'medium';
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('Medium confidence');
  });
});
