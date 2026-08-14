import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import en from '../../../assets/i18n/en.json';
import { clearLearnProposalApplicationProgressCache } from '../../domain/plans/learn-proposal-application-progress';
import { GDD_VARIANCE_THRESHOLD } from '../../domain/plans/plan-variance-thresholds';
import { PlanLearnProposalQueueComponent } from './plan-learn-proposal-queue.component';

describe('PlanLearnProposalQueueComponent', () => {
  let fixture: ComponentFixture<PlanLearnProposalQueueComponent>;

  beforeEach(async () => {
    sessionStorage.clear();
    clearLearnProposalApplicationProgressCache();

    await TestBed.configureTestingModule({
      imports: [PlanLearnProposalQueueComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture = TestBed.createComponent(PlanLearnProposalQueueComponent);
    fixture.componentInstance.planId = 7;
  });

  it('renders prioritized tiers when proposals span safe, needs_review, and action_required', () => {
    fixture.componentInstance.stageGddProposals = [
      {
        cropId: 1,
        cropName: 'Tomato',
        stageId: 2,
        stageOrder: 1,
        stageName: 'Vegetative',
        averageGddDelta: 5,
        recordedItemCount: 2,
        currentRequiredGdd: 100,
        proposedRequiredGdd: 105
      },
      {
        cropId: 1,
        cropName: 'Tomato',
        stageId: 3,
        stageOrder: 2,
        stageName: 'Fruit',
        averageGddDelta: GDD_VARIANCE_THRESHOLD + 10,
        recordedItemCount: 2,
        currentRequiredGdd: 200,
        proposedRequiredGdd: 250
      }
    ];
    fixture.componentInstance.actionRequiredItems = [
      {
        item_id: 10,
        field_cultivation_id: 20,
        category: 'general',
        name: 'Transplant',
        scheduled_date: '2026-03-01',
        actual_date: '2026-03-10',
        delta_days: 9,
        gdd_trigger: 120,
        gdd_at_actual: 130,
        gdd_delta: 10,
        exceedance_kind: 'days'
      }
    ];
    fixture.detectChanges();

    const tiers = fixture.nativeElement.querySelectorAll('[data-queue-tier]');
    expect(tiers.length).toBe(3);
    expect(tiers[0].getAttribute('data-queue-tier')).toBe('action_required');
    expect(tiers[1].getAttribute('data-queue-tier')).toBe('needs_review');
    expect(tiers[2].getAttribute('data-queue-tier')).toBe('safe');
    expect(fixture.nativeElement.textContent).toContain('Transplant');
    expect(fixture.nativeElement.textContent).toContain('Vegetative');
  });

  it('hides queue section when no pending proposals exist', () => {
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('.learn-proposal-queue')).toBeNull();
  });
});
