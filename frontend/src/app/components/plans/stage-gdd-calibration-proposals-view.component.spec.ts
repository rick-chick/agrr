import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  clearLearnProposalApplicationProgressCache,
  markLearnProposalConfirmed,
  resolveLearnProposalApplicationStatus,
  stageGddProposalProgressKey
} from '../../domain/plans/learn-proposal-application-progress';
import { ApplyStageGddCalibrationFromLearnUseCase } from '../../usecase/plans/apply-stage-gdd-calibration-from-learn.usecase';
import { StageGddCalibrationProposalsViewComponent } from './stage-gdd-calibration-proposals-view.component';

const sampleProposal = {
  cropId: 1,
  cropName: 'Tomato',
  stageId: 2,
  stageOrder: 1,
  stageName: 'Vegetative',
  averageGddDelta: 10,
  recordedItemCount: 3,
  currentRequiredGdd: 100,
  proposedRequiredGdd: 150
};

describe('StageGddCalibrationProposalsViewComponent inline apply', () => {
  let fixture: ComponentFixture<StageGddCalibrationProposalsViewComponent>;
  let applyUseCase: { execute: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    sessionStorage.clear();
    clearLearnProposalApplicationProgressCache();
    applyUseCase = {
      execute: vi.fn(({ onSuccess }: { onSuccess?: () => void }) => {
        markLearnProposalConfirmed(7, stageGddProposalProgressKey(1, 2));
        onSuccess?.();
      })
    };

    TestBed.overrideComponent(StageGddCalibrationProposalsViewComponent, {
      set: {
        providers: [
          { provide: ApplyStageGddCalibrationFromLearnUseCase, useValue: applyUseCase }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [StageGddCalibrationProposalsViewComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        'plans.learn.stage_gdd_calibration.title': 'Stage GDD calibration proposals',
        'plans.learn.stage_gdd_calibration.lead': 'Lead',
        'plans.learn.stage_gdd_calibration.delta_label': 'Delta {{delta}}',
        'plans.learn.stage_gdd_calibration.proposed_value': '{{current}} → {{proposed}}',
        'plans.learn.stage_gdd_calibration.preview': 'Preview',
        'plans.learn.stage_gdd_calibration.apply': 'Apply',
        'plans.learn.stage_gdd_calibration.detail_edit': 'Detail edit',
        'plans.learn.stage_gdd_calibration.preview_panel': 'Proposed required GDD: {{proposed}}',
        'plans.learn.proposal.dismiss': 'Do not apply',
        'plans.learn.application_progress.status.not_started': 'Not applied',
        'plans.learn.application_progress.status.confirmed': 'Confirmed',
        'plans.learn.stage_gdd_calibration.evidence.toggle': 'Show rationale',
        'plans.learn.stage_gdd_calibration.evidence.rationale': 'Rationale',
        'plans.learn.stage_gdd_calibration.evidence.records_title': 'Records',
        'plans.learn.stage_gdd_calibration.evidence.record': 'Record'
      },
      true
    );
    translate.use('en');

    fixture = TestBed.createComponent(StageGddCalibrationProposalsViewComponent);
    fixture.componentRef.setInput('planId', 7);
    fixture.componentRef.setInput('proposals', [sampleProposal]);
    fixture.detectChanges();
  });

  it('shows preview, apply, and detail edit buttons for not_started proposals', () => {
    const buttons = Array.from(fixture.nativeElement.querySelectorAll('button')).map(
      (el: Element) => el.textContent?.trim()
    );
    const links = Array.from(fixture.nativeElement.querySelectorAll('a')).map(
      (el: Element) => el.textContent?.trim()
    );

    expect(buttons).toContain('Preview');
    expect(buttons).toContain('Apply');
    expect(links).toContain('Detail edit');
  });

  it('applies proposal inline and transitions status to confirmed', () => {
    const applyButton = Array.from(fixture.nativeElement.querySelectorAll('button')).find(
      (el: Element) => el.textContent?.trim() === 'Apply'
    ) as HTMLButtonElement;
    applyButton.click();
    fixture.detectChanges();

    expect(applyUseCase.execute).toHaveBeenCalled();
    expect(
      resolveLearnProposalApplicationStatus(7, stageGddProposalProgressKey(1, 2))
    ).toBe('confirmed');
    expect(fixture.nativeElement.textContent).toContain('Confirmed');
  });

  it('toggles preview panel when preview is clicked', () => {
    const previewButton = Array.from(fixture.nativeElement.querySelectorAll('button')).find(
      (el: Element) => el.textContent?.trim() === 'Preview'
    ) as HTMLButtonElement;

    previewButton.click();
    fixture.detectChanges();
    expect(fixture.nativeElement.textContent).toContain('Proposed required GDD: 150');

    previewButton.click();
    fixture.detectChanges();
    expect(fixture.nativeElement.textContent).not.toContain('Proposed required GDD: 150');
  });
});
