import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import en from '../../../assets/i18n/en.json';
import type { BlueprintTimingAdjustmentProposal } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import { BLUEPRINT_TIMING_PATCH_INTENT } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import {
  clearLearnProposalApplicationProgressCache,
  markBpTimingProposalAppliedPending,
  storeLearnPostMasterPayload
} from '../../domain/plans/learn-proposal-application-progress';
import {
  clearLearnReorganizePipelineAutoChain,
  readLearnReorganizePipelineAutoChain
} from '../../domain/plans/learn-reorganize-pipeline-auto-chain';
import { clearLearnOrchestrationProgressCache } from '../../domain/plans/learn-master-update-orchestration';
import { BulkApplySafeLearnProposalsUseCase } from '../../usecase/plans/bulk-apply-safe-learn-proposals.usecase';
import { PlanLearnProposalQueueComponent } from './plan-learn-proposal-queue.component';

const fertilizerBpTimingProposal = (): BlueprintTimingAdjustmentProposal => ({
  cropId: 1,
  cropName: 'Tomato',
  category: 'fertilizer',
  averageDeltaDays: 2,
  averageGddDelta: 5,
  recordedItemCount: 3,
  affectedBlueprintCount: 2,
  proposalBody: {
    intent: BLUEPRINT_TIMING_PATCH_INTENT,
    stages: [],
    agricultural_tasks: [],
    task_schedule_blueprints: [{ blueprint_id: 10, gdd_trigger: 120 }]
  }
});

describe('PlanLearnProposalQueueComponent', () => {
  let fixture: ComponentFixture<PlanLearnProposalQueueComponent>;
  let bulkApplyUseCase: { execute: ReturnType<typeof vi.fn> };
  let router: Router;

  beforeEach(async () => {
    sessionStorage.clear();
    clearLearnProposalApplicationProgressCache();
    clearLearnOrchestrationProgressCache();
    clearLearnReorganizePipelineAutoChain();

    bulkApplyUseCase = {
      execute: vi.fn(({ onSuccess }: { onSuccess?: (result: { appliedCount: number; totalSafeCount: number }) => void }) => {
        onSuccess?.({ appliedCount: 1, totalSafeCount: 1 });
      })
    };

    await TestBed.configureTestingModule({
      imports: [PlanLearnProposalQueueComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: BulkApplySafeLearnProposalsUseCase, useValue: bulkApplyUseCase }
      ]
    })
      .overrideComponent(PlanLearnProposalQueueComponent, {
        set: {
          providers: [{ provide: BulkApplySafeLearnProposalsUseCase, useValue: bulkApplyUseCase }]
        }
      })
      .compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture = TestBed.createComponent(PlanLearnProposalQueueComponent);
    fixture.componentInstance.planId = 7;
    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigate').mockResolvedValue(true);
  });

  it('renders categorized proposal queue with observable counts', () => {
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
        stageName: 'Flowering',
        averageGddDelta: 50,
        recordedItemCount: 2,
        currentRequiredGdd: 200,
        proposedRequiredGdd: 250
      }
    ];
    fixture.componentInstance.actionRequiredItems = [
      {
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
      }
    ];
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('Proposal queue');
    expect(fixture.nativeElement.textContent).toContain('Requires your action');
    expect(fixture.nativeElement.textContent).toContain('Requires confirmation');
    expect(fixture.nativeElement.textContent).toContain('Safe to apply');
    expect(fixture.nativeElement.textContent).toContain('Weed control');
    expect(fixture.nativeElement.textContent).toContain('Tomato — Flowering');
    expect(fixture.nativeElement.textContent).toContain('Tomato — Vegetative');
    expect(fixture.nativeElement.querySelector('[data-testid="queue-count-requires_action"]')?.textContent).toContain('1');
    expect(fixture.nativeElement.querySelector('[data-testid="queue-count-requires_confirmation"]')?.textContent).toContain('1');
    expect(fixture.nativeElement.querySelector('[data-testid="queue-count-safe"]')?.textContent).toContain('1');
  });

  it('shows post-apply confirmation on same screen after bulk apply without auto navigation', async () => {
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
      }
    ];
    fixture.detectChanges();

    const applyButton = fixture.nativeElement.querySelector(
      '.learn-proposal-queue__bulk-apply .btn-primary'
    ) as HTMLButtonElement;
    applyButton.click();
    fixture.detectChanges();
    await new Promise((resolve) => setTimeout(resolve, 0));
    fixture.detectChanges();
    await fixture.whenStable();

    expect(bulkApplyUseCase.execute).toHaveBeenCalled();
    expect(router.navigate).not.toHaveBeenCalled();
    expect(fixture.nativeElement.textContent).toContain('1 safe proposal(s) applied');
    expect(fixture.nativeElement.textContent).toContain('Start reorganization pipeline');
    expect(fixture.nativeElement.querySelector('.learn-proposal-queue__post-apply')).toBeTruthy();
  });

  it('starts reorganize pipeline only when user confirms post-apply step', () => {
    fixture.componentInstance.bulkApplyComplete = true;
    fixture.componentInstance.lastAppliedCount = 2;
    fixture.detectChanges();

    const startButton = fixture.nativeElement.querySelector(
      '.learn-proposal-queue__post-apply .btn-primary'
    ) as HTMLButtonElement;
    startButton.click();

    expect(readLearnReorganizePipelineAutoChain(7)).toBe(true);
    expect(router.navigate).toHaveBeenCalledWith(['/plans', 7], {
      queryParams: { learningOrchestration: 'adjust' }
    });
  });

  it('renders post_master confirmation within the queue when payload is set', () => {
    storeLearnPostMasterPayload(7, {
      kind: 'stage_gdd',
      cropId: 1,
      cropName: 'Tomato',
      stageId: 2,
      stageName: 'Vegetative',
      appliedRequiredGdd: 150
    });
    fixture.componentInstance.postMasterPayload = {
      kind: 'stage_gdd',
      cropId: 1,
      cropName: 'Tomato',
      stageId: 2,
      stageName: 'Vegetative',
      appliedRequiredGdd: 150
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-plan-learn-post-master-confirmation')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Master update applied');
  });

  it('renders dedicated fertilizer timing section with evidence and application status', () => {
    fixture.componentInstance.blueprintTimingProposals = [fertilizerBpTimingProposal()];
    fixture.componentInstance.blueprintTimingEvidenceByKey = {
      '1-fertilizer': {
        exceedanceCount: 2,
        thresholdValue: 3,
        totalRecordedCount: 3,
        contributingRecords: [
          { name: 'Basal fertilization', actualDate: '2026-05-01' },
          { name: 'Topdress', actualDate: '2026-06-01' }
        ]
      }
    };
    markBpTimingProposalAppliedPending(7, { cropId: 1, category: 'fertilizer' });
    fixture.detectChanges();

    const section = fixture.nativeElement.querySelector(
      '[data-testid="fertilizer-timing-section"]'
    );
    expect(section).toBeTruthy();
    expect(section.textContent).toContain('Fertilization timing proposals');
    expect(section.textContent).toContain('Tomato');
    expect(section.textContent).toContain('Fertilization');
    expect(section.textContent).toContain('field.schedules.fertilizer');
    expect(section.textContent).toContain('Applied — pending confirmation');
    expect(section.querySelector('app-learn-proposal-evidence-panel')).toBeTruthy();
    expect(
      fixture.nativeElement.querySelector('[data-testid="queue-category-safe"]')
    ).toBeFalsy();
  });

  it('keeps general bp_timing in category sections when fertilizer section is shown', () => {
    fixture.componentInstance.blueprintTimingProposals = [
      fertilizerBpTimingProposal(),
      {
        ...fertilizerBpTimingProposal(),
        category: 'general',
        cropId: 2,
        cropName: 'Pepper'
      }
    ];
    fixture.detectChanges();

    expect(
      fixture.nativeElement.querySelector('[data-testid="fertilizer-timing-section"]')
    ).toBeTruthy();
    expect(fixture.nativeElement.querySelector('[data-testid="queue-category-safe"]')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Pepper');
  });
});
