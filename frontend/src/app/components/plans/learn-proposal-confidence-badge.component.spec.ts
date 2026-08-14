import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { LearnProposalConfidenceBadgeComponent } from './learn-proposal-confidence-badge.component';

describe('LearnProposalConfidenceBadgeComponent', () => {
  let fixture: ComponentFixture<LearnProposalConfidenceBadgeComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [LearnProposalConfidenceBadgeComponent, TranslateModule.forRoot()]
    }).compileComponents();

    translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation(
      'ja',
      {
        'plans.learn.proposal_confidence.label': '信頼度',
        'plans.learn.proposal_confidence.high': '高',
        'plans.learn.proposal_confidence.medium': '中',
        'plans.learn.proposal_confidence.low': '低'
      },
      true
    );

    fixture = TestBed.createComponent(LearnProposalConfidenceBadgeComponent);
  });

  it('renders low confidence label and class', () => {
    fixture.componentRef.setInput('confidence', 'low');
    fixture.detectChanges();

    const badge = fixture.nativeElement.querySelector('.learn-proposal-confidence-badge');
    expect(badge).toBeTruthy();
    expect(badge.classList.contains('learn-proposal-confidence-badge--low')).toBe(true);
    expect(badge.textContent).toContain('信頼度');
    expect(badge.textContent).toContain('低');
  });

  it('renders medium confidence label and class', () => {
    fixture.componentRef.setInput('confidence', 'medium');
    fixture.detectChanges();

    const badge = fixture.nativeElement.querySelector('.learn-proposal-confidence-badge');
    expect(badge.classList.contains('learn-proposal-confidence-badge--medium')).toBe(true);
    expect(badge.textContent).toContain('中');
  });

  it('renders high confidence label and class', () => {
    fixture.componentRef.setInput('confidence', 'high');
    fixture.detectChanges();

    const badge = fixture.nativeElement.querySelector('.learn-proposal-confidence-badge');
    expect(badge.classList.contains('learn-proposal-confidence-badge--high')).toBe(true);
    expect(badge.textContent).toContain('高');
  });
});
