import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PlanLearnPipelineStatusComponent } from './plan-learn-pipeline-status.component';
import {
  clearLearnOrchestrationProgressCache,
  hydrateLearnOrchestrationProgress
} from '../../domain/plans/learn-master-update-orchestration';
import { storeLearnReorganizePipelineAutoChain } from '../../domain/plans/learn-reorganize-pipeline-auto-chain';
import { StartLearnVarianceLearningReoptimizeUseCase } from '../../usecase/plans/start-learn-variance-learning-reoptimize.usecase';

describe('PlanLearnPipelineStatusComponent', () => {
  let fixture: ComponentFixture<PlanLearnPipelineStatusComponent>;
  let reoptimizeUseCase: { execute: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    clearLearnOrchestrationProgressCache();
    reoptimizeUseCase = { execute: vi.fn((dto) => dto.onSuccess?.()) };

    await TestBed.configureTestingModule({
      imports: [PlanLearnPipelineStatusComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: StartLearnVarianceLearningReoptimizeUseCase, useValue: reoptimizeUseCase }
      ]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.learn.pipeline_status.failed_title': 'Reorganization pipeline failed',
        'plans.learn.pipeline_status.unknown_error': 'Unknown error',
        'plans.learn.pipeline_status.retry': 'Retry pipeline',
        'plans.learn.pipeline_status.resume': 'Resume pipeline',
        'plans.learn.pipeline_status.active_message': 'Pipeline in progress',
        'plans.learn.pipeline_status.stage.adjust': 'Current step: Placement adjustment',
        'plans.learn.pipeline_status.stage.optimizing': 'Current step: Optimization',
        'plans.learn.pipeline_status.stage.task_schedule': 'Current step: Task schedule',
        'plans.learn.pipeline_status.step.placement': 'Placement adjustment',
        'plans.learn.pipeline_status.step.regenerate': 'Task schedule regeneration',
        'plans.learn.pipeline_status.step.sync_verify': 'Sync verification'
      },
      true
    );

    fixture = TestBed.createComponent(PlanLearnPipelineStatusComponent);
    fixture.componentInstance.planId = 7;
  });

  it('shows active pipeline stage label for placement phase', () => {
    storeLearnReorganizePipelineAutoChain(7);
    fixture.detectChanges();

    const section = fixture.nativeElement.querySelector('.learn-pipeline-status--active');
    expect(section).not.toBeNull();
    expect(section.textContent).toContain('Current step: Placement adjustment');
    expect(section.textContent).toContain('Resume pipeline');
  });

  it('shows optimizing stage label when pipeline phase is optimizing', () => {
    hydrateLearnOrchestrationProgress(7, {
      pipeline_active: true,
      current_phase: 'optimizing'
    });
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('Current step: Optimization');
  });

  it('shows failure UI with retry when pipeline failed', () => {
    hydrateLearnOrchestrationProgress(7, {
      pipeline_active: true,
      current_phase: 'failed',
      last_error: 'timeout'
    });
    fixture.detectChanges();

    const alert = fixture.nativeElement.querySelector('[role="alert"]');
    expect(alert).not.toBeNull();
    expect(alert.textContent).toContain('Reorganization pipeline failed');
    expect(alert.textContent).toContain('timeout');
    expect(alert.textContent).toContain('Retry pipeline');
  });

  it('shows orchestration step summary while pipeline is active', () => {
    hydrateLearnOrchestrationProgress(7, {
      pipeline_active: true,
      current_phase: 'optimizing',
      placement: true,
      regenerate: false,
      sync_verify: false
    });
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('Placement adjustment');
    expect(fixture.nativeElement.textContent).toContain('Task schedule regeneration');
    expect(fixture.nativeElement.textContent).toContain('Sync verification');
  });

  it('retries pipeline via server reoptimize enqueue', () => {
    hydrateLearnOrchestrationProgress(7, {
      pipeline_active: true,
      current_phase: 'failed',
      last_error: 'timeout'
    });
    fixture.detectChanges();

    const retryButton = fixture.nativeElement.querySelector(
      '.learn-pipeline-status__actions button'
    ) as HTMLButtonElement;
    retryButton.click();

    expect(reoptimizeUseCase.execute).toHaveBeenCalledWith(
      expect.objectContaining({ planId: 7 })
    );
  });
});
