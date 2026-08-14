import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PlanLearnPipelineStatusComponent } from './plan-learn-pipeline-status.component';
import {
  clearLearnOrchestrationProgressCache,
  hydrateLearnOrchestrationProgress
} from '../../domain/plans/learn-master-update-orchestration';
import { storeLearnReorganizePipelineAutoChain } from '../../domain/plans/learn-reorganize-pipeline-auto-chain';

describe('PlanLearnPipelineStatusComponent', () => {
  let fixture: ComponentFixture<PlanLearnPipelineStatusComponent>;
  let router: Router;

  beforeEach(async () => {
    clearLearnOrchestrationProgressCache();

    await TestBed.configureTestingModule({
      imports: [PlanLearnPipelineStatusComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
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
        'plans.learn.pipeline_status.stage.task_schedule': 'Current step: Task schedule'
      },
      true
    );

    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigate').mockResolvedValue(true);

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

  it('retries pipeline from learn screen', () => {
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

    expect(router.navigate).toHaveBeenCalledWith(['/plans', 7], {
      queryParams: { learningOrchestration: 'adjust' }
    });
  });
});
