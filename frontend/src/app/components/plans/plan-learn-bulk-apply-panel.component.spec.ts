import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import en from '../../../assets/i18n/en.json';
import { BLUEPRINT_TIMING_PATCH_INTENT } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import {
  clearLearnProposalApplicationProgressCache
} from '../../domain/plans/learn-proposal-application-progress';
import {
  clearLearnReorganizePipelineAutoChain,
  readLearnReorganizePipelineAutoChain
} from '../../domain/plans/learn-reorganize-pipeline-auto-chain';
import { BulkApplySafeLearnProposalsUseCase } from '../../usecase/plans/bulk-apply-safe-learn-proposals.usecase';
import { PlanLearnBulkApplyPanelComponent } from './plan-learn-bulk-apply-panel.component';

describe('PlanLearnBulkApplyPanelComponent', () => {
  let fixture: ComponentFixture<PlanLearnBulkApplyPanelComponent>;
  let bulkApplyUseCase: { execute: ReturnType<typeof vi.fn> };
  let router: Router;

  beforeEach(async () => {
    sessionStorage.clear();
    clearLearnProposalApplicationProgressCache();
    clearLearnReorganizePipelineAutoChain();

    bulkApplyUseCase = {
      execute: vi.fn(({ onSuccess }: { onSuccess?: (result: { appliedCount: number; totalSafeCount: number }) => void }) => {
        onSuccess?.({ appliedCount: 1, totalSafeCount: 1 });
      })
    };

    await TestBed.configureTestingModule({
      imports: [PlanLearnBulkApplyPanelComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: BulkApplySafeLearnProposalsUseCase, useValue: bulkApplyUseCase }
      ]
    })
      .overrideComponent(PlanLearnBulkApplyPanelComponent, {
        set: {
          providers: [{ provide: BulkApplySafeLearnProposalsUseCase, useValue: bulkApplyUseCase }]
        }
      })
      .compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture = TestBed.createComponent(PlanLearnBulkApplyPanelComponent);
    fixture.componentInstance.planId = 7;
    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigate').mockResolvedValue(true);
  });

  it('shows bulk apply CTA when safe proposals exist', () => {
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

    expect(fixture.nativeElement.textContent).toContain('Apply all safe proposals');
    expect(fixture.nativeElement.textContent).toContain('(1)');
  });

  it('hides panel when no safe proposals exist', () => {
    fixture.componentInstance.stageGddProposals = [
      {
        cropId: 1,
        cropName: 'Tomato',
        stageId: 2,
        stageOrder: 1,
        stageName: 'Vegetative',
        averageGddDelta: 50,
        recordedItemCount: 2,
        currentRequiredGdd: 100,
        proposedRequiredGdd: 150
      }
    ];
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.learn-bulk-apply')).toBeNull();
  });

  it('applies safe proposals and shows reorganize pipeline CTA', async () => {
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
      '.learn-bulk-apply .btn-primary'
    ) as HTMLButtonElement;
    applyButton.click();
    fixture.detectChanges();
    await new Promise((resolve) => setTimeout(resolve, 0));
    fixture.detectChanges();
    await fixture.whenStable();

    expect(bulkApplyUseCase.execute).toHaveBeenCalled();
    expect(fixture.nativeElement.textContent).toContain('Start reorganization pipeline');
  });

  it('navigates to adjust with auto-chain when pipeline CTA is clicked', () => {
    fixture.componentInstance.bulkApplyComplete = true;
    fixture.componentInstance.lastAppliedCount = 1;
    fixture.detectChanges();

    fixture.componentInstance.startReorganizePipeline();
    expect(router.navigate).toHaveBeenCalledWith(['/plans', 7], {
      queryParams: { learningOrchestration: 'adjust' }
    });
    expect(readLearnReorganizePipelineAutoChain(7)).toBe(true);
  });
});
