import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  bpAmountProposalProgressKey,
  clearLearnProposalApplicationProgressCache,
  markLearnProposalConfirmed,
  resolveLearnProposalApplicationStatus
} from '../../domain/plans/learn-proposal-application-progress';
import { ApplyBpAmountProposalFromLearnUseCase } from '../../usecase/plans/apply-bp-amount-proposal-from-learn.usecase';
import { DryRunBpAmountProposalFromLearnUseCase } from '../../usecase/plans/dry-run-bp-amount-proposal-from-learn.usecase';
import { BlueprintAmountAdjustmentProposalsViewComponent } from './blueprint-amount-adjustment-proposals-view.component';

const proposalBody = {
  intent: 'blueprint_amount_patch',
  stages: [],
  agricultural_tasks: [],
  task_schedule_blueprints: [{ blueprint_id: 10, amount: 2.5, amount_unit: 'kg' }]
};

const sampleProposal = {
  cropId: 1,
  cropName: 'Tomato',
  category: 'fertilizer',
  taskType: 'fertilize',
  stageOrder: 1,
  stageName: 'Vegetative',
  averageAmountDelta: 0.5,
  recordedItemCount: 2,
  amountUnit: 'kg',
  affectedBlueprintCount: 1,
  proposalBody
};

describe('BlueprintAmountAdjustmentProposalsViewComponent inline apply', () => {
  let fixture: ComponentFixture<BlueprintAmountAdjustmentProposalsViewComponent>;
  let applyUseCase: { execute: ReturnType<typeof vi.fn> };
  let dryRunUseCase: { execute: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    sessionStorage.clear();
    clearLearnProposalApplicationProgressCache();
    applyUseCase = {
      execute: vi.fn(({ onSuccess }: { onSuccess?: () => void }) => {
        markLearnProposalConfirmed(7, bpAmountProposalProgressKey(1, 'fertilizer', 'fertilize', 1));
        onSuccess?.();
      })
    };
    dryRunUseCase = {
      execute: vi.fn(({ onSuccess }: { onSuccess?: (preview: string) => void }) => {
        onSuccess?.('{"task_schedule_blueprints":[{"blueprint_id":10}]}');
      })
    };

    TestBed.overrideComponent(BlueprintAmountAdjustmentProposalsViewComponent, {
      set: {
        providers: [
          { provide: ApplyBpAmountProposalFromLearnUseCase, useValue: applyUseCase },
          { provide: DryRunBpAmountProposalFromLearnUseCase, useValue: dryRunUseCase }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [BlueprintAmountAdjustmentProposalsViewComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        'plans.learn.bp_amount_adjustment.title': 'BP amount',
        'plans.learn.bp_amount_adjustment.lead': 'Lead',
        'plans.learn.bp_amount_adjustment.empty': 'No amount proposals',
        'plans.learn.bp_amount_adjustment.delta_label': 'Delta {{delta}}',
        'plans.learn.bp_amount_adjustment.affected_count': 'BPs {{count}}',
        'plans.learn.bp_amount_adjustment.category.fertilizer': 'Fertilization',
        'plans.learn.bp_amount_adjustment.task_type.fertilize': 'Fertilize',
        'plans.learn.bp_amount_adjustment.stage_label': 'Stage {{order}} — {{name}}',
        'plans.learn.bp_amount_adjustment.detail_edit': 'Detail edit',
        'plans.learn.bp_amount_adjustment.dry_run_preview': 'Dry-run preview',
        'plans.learn.bp_amount_adjustment.apply': 'Apply',
        'plans.learn.bp_amount_adjustment.dry_run_result': 'Dry-run result',
        'plans.learn.proposal.dismiss': 'Do not apply',
        'plans.learn.application_progress.status.not_started': 'Not applied',
        'plans.learn.application_progress.status.confirmed': 'Confirmed',
        'plans.learn.application_progress.status.dismissed': 'Dismissed',
        'plans.learn.bp_amount_adjustment.evidence.toggle': 'Show rationale',
        'plans.learn.bp_amount_adjustment.evidence.rationale': 'Rationale',
        'plans.learn.bp_amount_adjustment.evidence.records_title': 'Records',
        'plans.learn.bp_amount_adjustment.evidence.record': 'Record'
      },
      true
    );
    translate.use('en');

    fixture = TestBed.createComponent(BlueprintAmountAdjustmentProposalsViewComponent);
    fixture.componentRef.setInput('planId', 7);
    fixture.componentRef.setInput('proposals', [sampleProposal]);
    fixture.detectChanges();
  });

  it('shows dry_run preview, apply, and detail edit buttons', () => {
    const buttons = Array.from(fixture.nativeElement.querySelectorAll('button')).map(
      (el: Element) => el.textContent?.trim()
    );

    expect(buttons).toContain('Dry-run preview');
    expect(buttons).toContain('Apply');
    expect(buttons).toContain('Detail edit');
  });

  it('exposes a stage_order anchor id for proposal cards', () => {
    const item = fixture.nativeElement.querySelector('.blueprint-amount-adjustment__item');
    expect(item?.id).toBe('plan-learn-bp-amount-proposal-1-fertilizer-fertilize');
    expect(item?.getAttribute('data-stage-order')).toBe('1');
    expect(fixture.nativeElement.textContent).toContain('Stage 1');
  });

  it('runs dry_run preview and shows result', () => {
    const previewButton = Array.from(fixture.nativeElement.querySelectorAll('button')).find(
      (el: Element) => el.textContent?.trim() === 'Dry-run preview'
    ) as HTMLButtonElement;
    previewButton.click();
    fixture.detectChanges();

    expect(dryRunUseCase.execute).toHaveBeenCalled();
    expect(fixture.nativeElement.textContent).toContain('Dry-run result');
    expect(fixture.nativeElement.textContent).toContain('task_schedule_blueprints');
  });

  it('applies proposal inline and transitions status to confirmed', () => {
    const applyButton = Array.from(fixture.nativeElement.querySelectorAll('button')).find(
      (el: Element) => el.textContent?.trim() === 'Apply'
    ) as HTMLButtonElement;
    applyButton.click();
    fixture.detectChanges();

    expect(applyUseCase.execute).toHaveBeenCalled();
    expect(
      resolveLearnProposalApplicationStatus(
        7,
        bpAmountProposalProgressKey(1, 'fertilizer', 'fertilize', 1)
      )
    ).toBe('confirmed');
    expect(fixture.nativeElement.textContent).toContain('Confirmed');
  });

  it('dismisses proposal and updates status', () => {
    const dismissButton = Array.from(fixture.nativeElement.querySelectorAll('button')).find(
      (el: Element) => el.textContent?.trim() === 'Do not apply'
    ) as HTMLButtonElement;
    dismissButton.click();
    fixture.detectChanges();

    expect(
      resolveLearnProposalApplicationStatus(
        7,
        bpAmountProposalProgressKey(1, 'fertilizer', 'fertilize', 1)
      )
    ).toBe('dismissed');
    expect(fixture.nativeElement.textContent).toContain('Dismissed');
  });

  it('navigates to setup_proposal on detail edit', () => {
    const router = TestBed.inject(Router);
    const navigateSpy = vi.spyOn(router, 'navigate').mockResolvedValue(true);

    const detailButton = Array.from(fixture.nativeElement.querySelectorAll('button')).find(
      (el: Element) => el.textContent?.trim() === 'Detail edit'
    ) as HTMLButtonElement;
    detailButton.click();

    expect(navigateSpy).toHaveBeenCalledWith(
      ['/crops', 1, 'setup_proposal'],
      expect.objectContaining({ queryParams: expect.objectContaining({ fromPlan: 7 }) })
    );
  });

  it('shows empty state when no proposals', () => {
    fixture.componentRef.setInput('proposals', []);
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('No amount proposals');
  });
});
