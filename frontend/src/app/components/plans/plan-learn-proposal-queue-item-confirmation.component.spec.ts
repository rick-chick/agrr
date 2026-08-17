import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import en from '../../../assets/i18n/en.json';
import { BLUEPRINT_TIMING_PATCH_INTENT } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import type { BlueprintTimingAdjustmentProposal } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import type { UnifiedLearnProposalQueueItem } from '../../domain/plans/build-unified-learn-proposal-queue';
import {
  bpTimingProposalProgressKey,
  clearLearnProposalApplicationProgressCache,
  resolveLearnProposalApplicationStatus
} from '../../domain/plans/learn-proposal-application-progress';
import { ApplyBpTimingProposalFromLearnUseCase } from '../../usecase/plans/apply-bp-timing-proposal-from-learn.usecase';
import { ApplyStageGddCalibrationFromLearnUseCase } from '../../usecase/plans/apply-stage-gdd-calibration-from-learn.usecase';
import { DryRunBpTimingProposalFromLearnUseCase } from '../../usecase/plans/dry-run-bp-timing-proposal-from-learn.usecase';
import { PlanLearnProposalQueueItemConfirmationComponent } from './plan-learn-proposal-queue-item-confirmation.component';

const bpTimingItem: UnifiedLearnProposalQueueItem = {
  id: 'bp_timing:1:fertilizer',
  kind: 'bp_timing',
  category: 'requires_confirmation',
  priority: 1000,
  title: 'Tomato',
  subtitle: 'fertilizer',
  bpTimingCategory: 'fertilizer'
};

const bpTimingProposal = (): BlueprintTimingAdjustmentProposal => ({
  cropId: 1,
  cropName: 'Tomato',
  category: 'fertilizer',
  averageDeltaDays: 3,
  averageGddDelta: 5,
  recordedItemCount: 2,
  affectedBlueprintCount: 1,
  proposalBody: {
    intent: BLUEPRINT_TIMING_PATCH_INTENT,
    stages: [],
    agricultural_tasks: [],
    task_schedule_blueprints: [{ blueprint_id: 10, gdd_trigger: 120 }]
  }
});

describe('PlanLearnProposalQueueItemConfirmationComponent', () => {
  let fixture: ComponentFixture<PlanLearnProposalQueueItemConfirmationComponent>;
  let router: Router;
  let applyBpTimingUseCase: { execute: ReturnType<typeof vi.fn> };
  let dryRunUseCase: { execute: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    sessionStorage.clear();
    clearLearnProposalApplicationProgressCache();

    applyBpTimingUseCase = {
      execute: vi.fn(({ onSuccess }: { onSuccess?: () => void }) => onSuccess?.())
    };
    dryRunUseCase = {
      execute: vi.fn(({ onSuccess }: { onSuccess?: (preview: string) => void }) =>
        onSuccess?.('{"preview":true}')
      )
    };

    await TestBed.configureTestingModule({
      imports: [PlanLearnProposalQueueItemConfirmationComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: ApplyStageGddCalibrationFromLearnUseCase, useValue: { execute: vi.fn() } },
        { provide: ApplyBpTimingProposalFromLearnUseCase, useValue: applyBpTimingUseCase },
        { provide: DryRunBpTimingProposalFromLearnUseCase, useValue: dryRunUseCase }
      ]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigate').mockResolvedValue(true);

    fixture = TestBed.createComponent(PlanLearnProposalQueueItemConfirmationComponent);
    fixture.componentInstance.planId = 7;
    fixture.componentInstance.item = bpTimingItem;
    fixture.componentInstance.bpTimingProposal = bpTimingProposal();
    fixture.detectChanges();
  });

  it('applies bp_timing proposal inline and emits progressChanged', async () => {
    const progressChanged = vi.fn();
    fixture.componentInstance.progressChanged.subscribe(progressChanged);

    const applyButton = fixture.nativeElement.querySelector(
      '[data-testid="queue-inline-apply"]'
    ) as HTMLButtonElement;
    applyButton.click();
    fixture.detectChanges();
    await fixture.whenStable();

    expect(applyBpTimingUseCase.execute).toHaveBeenCalledWith(
      expect.objectContaining({
        planId: 7,
        cropId: 1,
        category: 'fertilizer'
      })
    );
    expect(progressChanged).toHaveBeenCalled();
    expect(router.navigate).not.toHaveBeenCalled();
  });

  it('runs dry-run preview and renders result', async () => {
    const dryRunButton = Array.from(
      fixture.nativeElement.querySelectorAll('button')
    ).find((button: Element) => button.textContent?.includes('Dry-run preview')) as HTMLButtonElement;
    dryRunButton.click();
    fixture.detectChanges();
    await fixture.whenStable();

    expect(dryRunUseCase.execute).toHaveBeenCalledWith(
      expect.objectContaining({
        cropId: 1,
        proposal: bpTimingProposal().proposalBody
      })
    );
    expect(fixture.nativeElement.textContent).toContain('{"preview":true}');
  });

  it('shows apply error when bp_timing apply fails', async () => {
    applyBpTimingUseCase.execute = vi.fn(
      ({ onError }: { onError?: (message: string) => void }) =>
        onError?.('plans.learn.bp_timing_adjustment.error.apply_failed')
    );

    const applyButton = fixture.nativeElement.querySelector(
      '[data-testid="queue-inline-apply"]'
    ) as HTMLButtonElement;
    applyButton.click();
    fixture.detectChanges();
    await fixture.whenStable();

    const alert = fixture.nativeElement.querySelector('[role="alert"]');
    expect(alert).toBeTruthy();
    expect(alert.textContent).toContain('apply_failed');
  });

  it('dismisses bp_timing proposal and hides dismiss button afterward', async () => {
    const dismissButton = Array.from(
      fixture.nativeElement.querySelectorAll('button')
    ).find((button: Element) => button.textContent?.includes('Do not apply')) as HTMLButtonElement;
    expect(dismissButton).toBeTruthy();

    dismissButton.click();
    fixture.detectChanges();
    await fixture.whenStable();

    expect(
      resolveLearnProposalApplicationStatus(7, bpTimingProposalProgressKey(1, 'fertilizer'))
    ).toBe('dismissed');
    expect(
      Array.from(fixture.nativeElement.querySelectorAll('button')).some((button: Element) =>
        button.textContent?.includes('Do not apply')
      )
    ).toBe(false);
  });

  it('navigates to setup_proposal when detail edit is clicked', async () => {
    const detailEditButton = fixture.nativeElement.querySelector(
      '[data-testid="queue-inline-detail-edit"]'
    ) as HTMLButtonElement;
    detailEditButton.click();
    fixture.detectChanges();
    await fixture.whenStable();

    expect(router.navigate).toHaveBeenCalledWith(
      ['/crops', 1, 'setup_proposal'],
      expect.objectContaining({
        queryParams: expect.objectContaining({ fromPlan: 7, returnTo: 'learn' })
      })
    );
  });
});
