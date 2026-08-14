import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { of } from 'rxjs';
import {
  clearLearnProposalApplicationProgressCache,
  markLearnProposalConfirmed,
  stageGddProposalProgressKey
} from '../../domain/plans/learn-proposal-application-progress';
import {
  clearLearnOrchestrationProgressCache,
  readLearnOrchestrationPipelineActive
} from '../../domain/plans/learn-master-update-orchestration';
import { CROP_SETUP_PROPOSAL_GATEWAY } from '../../usecase/crops/crop-setup-proposal-gateway';
import { CROP_STAGE_GATEWAY } from '../../usecase/crops/crop-stage-gateway';
import { ApplyBpTimingProposalFromLearnUseCase } from '../../usecase/plans/apply-bp-timing-proposal-from-learn.usecase';
import { ApplyStageGddCalibrationFromLearnUseCase } from '../../usecase/plans/apply-stage-gdd-calibration-from-learn.usecase';
import { BulkApplySafeLearnProposalsUseCase } from '../../usecase/plans/bulk-apply-safe-learn-proposals.usecase';
import { DryRunBpTimingProposalFromLearnUseCase } from '../../usecase/plans/dry-run-bp-timing-proposal-from-learn.usecase';
import { PlanLearnBulkApplyPanelComponent } from './plan-learn-bulk-apply-panel.component';

describe('PlanLearnBulkApplyPanelComponent', () => {
  let fixture: ComponentFixture<PlanLearnBulkApplyPanelComponent>;
  let cropStageGateway: {
    getThermalRequirement: ReturnType<typeof vi.fn>;
    updateThermalRequirement: ReturnType<typeof vi.fn>;
    createThermalRequirement: ReturnType<typeof vi.fn>;
  };
  let setupProposalGateway: { apply: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    clearLearnProposalApplicationProgressCache();
    clearLearnOrchestrationProgressCache();
    cropStageGateway = {
      getThermalRequirement: vi.fn(() => of({ id: 1, crop_stage_id: 2, required_gdd: 100 })),
      updateThermalRequirement: vi.fn(() => of({ id: 1, crop_stage_id: 2, required_gdd: 105 })),
      createThermalRequirement: vi.fn()
    };
    setupProposalGateway = {
      apply: vi.fn(() => of({ valid: true }))
    };

    await TestBed.configureTestingModule({
      imports: [PlanLearnBulkApplyPanelComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: CROP_STAGE_GATEWAY, useValue: cropStageGateway },
        { provide: CROP_SETUP_PROPOSAL_GATEWAY, useValue: setupProposalGateway }
      ]
    })
      .overrideComponent(PlanLearnBulkApplyPanelComponent, {
        set: {
          providers: [
            BulkApplySafeLearnProposalsUseCase,
            ApplyStageGddCalibrationFromLearnUseCase,
            ApplyBpTimingProposalFromLearnUseCase,
            DryRunBpTimingProposalFromLearnUseCase,
            { provide: CROP_STAGE_GATEWAY, useValue: cropStageGateway },
            { provide: CROP_SETUP_PROPOSAL_GATEWAY, useValue: setupProposalGateway }
          ]
        }
      })
      .compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'common.loading': 'Loading',
        'plans.learn.bulk_apply.title': 'Bulk apply safe proposals',
        'plans.learn.bulk_apply.lead': '{{count}} safe proposal(s) can be applied at once.',
        'plans.learn.bulk_apply.cta': 'Apply {{count}} safe proposal(s)',
        'plans.learn.bulk_apply.pipeline_lead':
          'Master updates are confirmed. Start the re-optimization pipeline.',
        'plans.learn.bulk_apply.start_pipeline': 'Start re-optimization pipeline'
      },
      true
    );

    fixture = TestBed.createComponent(PlanLearnBulkApplyPanelComponent);
    fixture.componentInstance.planId = 7;
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
    fixture.componentInstance.blueprintTimingProposals = [];
  });

  it('renders bulk apply CTA for safe not_started proposals', () => {
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('Bulk apply safe proposals');
    expect(fixture.nativeElement.textContent).toContain('Apply 1 safe proposal(s)');
    expect(fixture.nativeElement.querySelector('button.learn-bulk-apply__cta')).toBeTruthy();
  });

  it('shows start pipeline CTA after bulk apply succeeds', async () => {
    fixture.detectChanges();
    fixture.nativeElement.querySelector('button.learn-bulk-apply__cta').click();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('Start re-optimization pipeline');
    const pipelineLink = fixture.nativeElement.querySelector('a.learn-bulk-apply__pipeline-cta');
    expect(pipelineLink.getAttribute('href')).toBe('/plans/7?learningOrchestration=adjust');
  });

  it('stores pipeline-active flag when start pipeline is clicked', () => {
    markLearnProposalConfirmed(7, stageGddProposalProgressKey(1, 2));
    fixture.componentInstance.bulkApplyCompleted = true;
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

    fixture.componentInstance.onStartPipeline();
    expect(readLearnOrchestrationPipelineActive(7)).toBe(true);
  });
});
