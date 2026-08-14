import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import en from '../../../assets/i18n/en.json';
import { clearLearnProposalApplicationProgressCache } from '../../domain/plans/learn-proposal-application-progress';
import {
  clearLearnOrchestrationAutoChain,
  isLearnOrchestrationAutoChainEnabled
} from '../../domain/plans/learn-orchestration-auto-chain';
import { BulkApplySafeLearnProposalsUseCase } from '../../usecase/plans/bulk-apply-safe-learn-proposals.usecase';
import { PlanLearnBulkApplyComponent } from './plan-learn-bulk-apply.component';

describe('PlanLearnBulkApplyComponent', () => {
  let fixture: ComponentFixture<PlanLearnBulkApplyComponent>;
  let component: PlanLearnBulkApplyComponent;
  let bulkApplyUseCase: { execute: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    sessionStorage.clear();
    clearLearnProposalApplicationProgressCache();
    clearLearnOrchestrationAutoChain();
    bulkApplyUseCase = {
      execute: vi.fn((dto) => {
        queueMicrotask(() => {
          dto.onComplete?.({ appliedCount: 2, failedCount: 0 });
        });
        return Promise.resolve();
      })
    };

    await TestBed.configureTestingModule({
      imports: [PlanLearnBulkApplyComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    })
      .overrideComponent(PlanLearnBulkApplyComponent, {
        set: {
          providers: [{ provide: BulkApplySafeLearnProposalsUseCase, useValue: bulkApplyUseCase }]
        }
      })
      .compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture = TestBed.createComponent(PlanLearnBulkApplyComponent);
    component = fixture.componentInstance;
    component.planId = 7;
    component.stageGddProposals = [
      {
        cropId: 1,
        cropName: 'Tomato',
        stageId: 2,
        stageOrder: 1,
        stageName: 'Vegetative',
        averageGddDelta: 5,
        recordedItemCount: 3,
        currentRequiredGdd: 100,
        proposedRequiredGdd: 105
      }
    ];
    component.blueprintTimingProposals = [
      {
        cropId: 3,
        cropName: 'Pepper',
        category: 'general',
        averageDeltaDays: 2,
        averageGddDelta: null,
        recordedItemCount: 2,
        affectedBlueprintCount: 1,
        proposalBody: { stages: [], agricultural_tasks: [], task_schedule_blueprints: [] }
      }
    ];
    component.ngOnChanges({});
    fixture.detectChanges();
  });

  it('shows bulk apply CTA for safe proposals', () => {
    expect(component.safeProposalCount).toBe(2);
    expect(fixture.nativeElement.querySelector('.plan-learn-bulk-apply__cta')).toBeTruthy();
  });

  it('runs bulk apply and marks completion', async () => {
    component.onBulkApply();
    await fixture.whenStable();

    expect(bulkApplyUseCase.execute).toHaveBeenCalled();
    expect(component.bulkApplyComplete).toBe(true);
    expect(component.appliedCount).toBe(2);
  });

  it('enables auto-chain when starting pipeline', () => {
    component.onStartPipeline();
    expect(isLearnOrchestrationAutoChainEnabled(7)).toBe(true);
  });
});
