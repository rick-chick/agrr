import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { clearLearnOrchestrationProgressCache } from '../../domain/plans/learn-master-update-orchestration';
import { markStageGddProposalAppliedPending, clearLearnProposalApplicationProgressCache } from '../../domain/plans/learn-proposal-application-progress';
import { StartLearnOneClickReoptimizeUseCase } from '../../usecase/plans/start-learn-one-click-reoptimize.usecase';
import { PlanLearnOneClickReoptimizeCtaComponent } from './plan-learn-one-click-reoptimize-cta.component';

describe('PlanLearnOneClickReoptimizeCtaComponent', () => {
  let fixture: ComponentFixture<PlanLearnOneClickReoptimizeCtaComponent>;
  let router: Router;
  let useCase: { execute: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    clearLearnOrchestrationProgressCache();
    clearLearnProposalApplicationProgressCache();
    useCase = { execute: vi.fn() };

    await TestBed.configureTestingModule({
      imports: [PlanLearnOneClickReoptimizeCtaComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: StartLearnOneClickReoptimizeUseCase, useValue: useCase }
      ]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.learn.one_click_reoptimize.title': 'Apply learning and re-optimize',
        'plans.learn.one_click_reoptimize.lead': 'Skip placement drag.',
        'plans.learn.one_click_reoptimize.cta': 'Apply learning and re-optimize',
        'plans.learn.one_click_reoptimize.starting': 'Starting…'
      },
      true
    );

    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigate').mockResolvedValue(true);

    fixture = TestBed.createComponent(PlanLearnOneClickReoptimizeCtaComponent);
    fixture.componentInstance.planId = 7;
  });

  it('shows CTA when master update flow is active', () => {
    markStageGddProposalAppliedPending(7, { cropId: 1, stageId: 2 });
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.learn-one-click-reoptimize')).not.toBeNull();
    expect(fixture.nativeElement.textContent).toContain('Apply learning and re-optimize');
  });

  it('starts skip-placement reoptimize and navigates to optimizing', () => {
    markStageGddProposalAppliedPending(7, { cropId: 1, stageId: 2 });
    useCase.execute.mockImplementation((dto) => dto.onSuccess?.());
    fixture.detectChanges();

    const button = fixture.nativeElement.querySelector(
      '.learn-one-click-reoptimize__cta'
    ) as HTMLButtonElement;
    button.click();

    expect(useCase.execute).toHaveBeenCalledWith(
      expect.objectContaining({ planId: 7 })
    );
    expect(router.navigate).toHaveBeenCalledWith(['/plans', 7, 'optimizing']);
  });

  it('does not render when master update flow is inactive', () => {
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('.learn-one-click-reoptimize')).toBeNull();
  });
});
