import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap, provideRouter, Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { of } from 'rxjs';

import { CropSetupProposalImportComponent } from './crop-setup-proposal-import.component';
import { CropSetupProposalImportPresenter } from '../../../usecase/crops/crop-setup-proposal-import.providers';
import { LoadCropForEditUseCase } from '../../../usecase/crops/load-crop-for-edit.usecase';
import { DryRunCropSetupProposalUseCase } from '../../../usecase/crops/dry-run-crop-setup-proposal.usecase';
import { ApplyCropSetupProposalUseCase } from '../../../usecase/crops/apply-crop-setup-proposal.usecase';
import { storeLearnBpTimingApplyContext } from '../../../domain/plans/learn-proposal-application-progress';

const validProposal = {
  stages: [{ name: '育苗', order: 1, thermal_requirement: { required_gdd: '120' } }],
  agricultural_tasks: [
    { ref: 'task-weeding', name: '除草', task_type: 'field_work', region: 'jp' }
  ],
  task_schedule_blueprints: [
    {
      agricultural_task_ref: 'task-weeding',
      stage_order: 1,
      stage_name: '育苗',
      gdd_trigger: 0,
      task_type: 'field_work',
      priority: 1
    }
  ]
};

const translations = {
  crops: {
    index: { title: 'Crops' },
    errors: { invalid_id: 'Invalid crop ID.' },
    setup_proposal_import: {
      title: 'Import proposal for {{name}}',
      lead: 'Paste or upload JSON from an external skill.',
      breadcrumb: 'Import proposal',
      json_label: 'Proposal JSON',
      json_placeholder: '{ "stages": [], ... }',
      choose_file: 'Choose file',
      paste_clipboard: 'Paste from clipboard',
      preview_button: 'Preview',
      previewing: 'Validating…',
      preview_title: 'Normalized preview',
      validation_errors_title: 'Validation errors',
      apply_button: 'Apply to crop',
      applying: 'Applying…',
      invalid_json: 'Invalid JSON.',
      invalid_shape: 'JSON must include stages, agricultural_tasks, and task_schedule_blueprints.',
      clipboard_error: 'Could not read clipboard.',
      l0_notice_ai_source: 'External AI/MCP proposal JSON.',
      l0_notice_dry_run: 'Preview validates before apply.',
      l0_notice_overwrite: 'Apply may overwrite crop master data.',
      l0_notice_label: 'AI proposal import notices',
      fix_and_preview_hint: 'Fix the JSON above and run Preview again.',
      success_title: 'Proposal applied',
      success_message: 'Crop master data was updated.',
      back_to_crop: 'Back to crop detail',
      validation_errors: {
        is_required: 'This field is required.',
        stage_order_conflict: 'Conflicts with an existing stage order.',
        generic: 'Validation failed.'
      }
    }
  },
  common: {
    loading: 'Loading...'
  }
};

describe('CropSetupProposalImportComponent', () => {
  let fixture: ComponentFixture<CropSetupProposalImportComponent>;
  let component: CropSetupProposalImportComponent;
  let mockLoadUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockDryRunUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockApplyUseCase: { execute: ReturnType<typeof vi.fn> };
  let presenter: CropSetupProposalImportPresenter;
  let mockRouter: Router;

  beforeEach(async () => {
    sessionStorage.clear();
    mockLoadUseCase = { execute: vi.fn() };
    mockDryRunUseCase = { execute: vi.fn() };
    mockApplyUseCase = { execute: vi.fn() };

    await TestBed.configureTestingModule({
      imports: [
        CropSetupProposalImportComponent,
        TranslateModule.forRoot({ fallbackLang: 'en' })
      ],
      providers: [
        provideRouter([]),
        {
          provide: ActivatedRoute,
          useValue: {
            snapshot: {
              paramMap: convertToParamMap({ id: '42' }),
              queryParamMap: convertToParamMap({})
            },
            paramMap: of(convertToParamMap({ id: '42' })),
            queryParamMap: of(convertToParamMap({}))
          }
        },
        { provide: LoadCropForEditUseCase, useValue: mockLoadUseCase },
        { provide: DryRunCropSetupProposalUseCase, useValue: mockDryRunUseCase },
        { provide: ApplyCropSetupProposalUseCase, useValue: mockApplyUseCase }
      ]
    }).compileComponents();

    TestBed.overrideProvider(LoadCropForEditUseCase, { useValue: mockLoadUseCase });
    TestBed.overrideProvider(DryRunCropSetupProposalUseCase, { useValue: mockDryRunUseCase });
    TestBed.overrideProvider(ApplyCropSetupProposalUseCase, { useValue: mockApplyUseCase });

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', translations, true);
    translate.use('en');

    fixture = TestBed.createComponent(CropSetupProposalImportComponent);
    component = fixture.componentInstance;
    presenter = fixture.debugElement.injector.get(CropSetupProposalImportPresenter);
    mockRouter = TestBed.inject(Router);
    vi.spyOn(mockRouter, 'navigate').mockResolvedValue(true);
    fixture.detectChanges();
  });

  it('should create and load crop on init', () => {
    expect(component).toBeTruthy();
    expect(mockLoadUseCase.execute).toHaveBeenCalledWith({ cropId: 42 });
  });

  it('shows L0 transparency notices below lead', () => {
    presenter.present({ crop: { id: 42, name: 'Tomato' } as never });
    fixture.detectChanges();

    const notice = fixture.nativeElement.querySelector('.crop-setup-proposal-import__l0-notice');
    expect(notice).toBeTruthy();
    expect(notice.textContent).toContain('External AI/MCP proposal JSON.');
    expect(notice.textContent).toContain('Preview validates before apply.');
    expect(notice.textContent).toContain('Apply may overwrite crop master data.');
  });

  it('dry_run success shows normalized preview', () => {
    component.control = {
      ...component.control,
      loading: false,
      cropName: 'Tomato',
      jsonInput: JSON.stringify(validProposal)
    };
    fixture.detectChanges();

    component.previewProposal();
    expect(mockDryRunUseCase.execute).toHaveBeenCalledWith({
      cropId: 42,
      proposal: validProposal
    });

    presenter.onDryRunSuccess({
      mode: 'dry_run',
      valid: true,
      normalized: validProposal
    });
    fixture.detectChanges();

    expect(component.control.phase).toBe('preview');
    expect(fixture.nativeElement.textContent).toContain('Normalized preview');
    expect(fixture.nativeElement.querySelector('.crop-setup-proposal-import__preview')).toBeTruthy();
  });

  it('dry_run validation failure shows field errors', () => {
    component.control = {
      ...component.control,
      loading: false,
      cropName: 'Tomato',
      jsonInput: JSON.stringify(validProposal)
    };
    fixture.detectChanges();

    component.previewProposal();

    presenter.onDryRunSuccess({
      mode: 'dry_run',
      valid: false,
      errors: [{ path: 'stages[0].thermal_requirement.required_gdd', message: 'is required' }]
    });
    fixture.detectChanges();

    expect(component.control.phase).toBe('validation_errors');
    expect(fixture.nativeElement.textContent).toContain('stages[0].thermal_requirement.required_gdd');
    expect(fixture.nativeElement.textContent).toContain('This field is required.');
    expect(fixture.nativeElement.textContent).toContain('Fix the JSON above and run Preview again.');
  });

  it('invalid JSON shows recovery hint without dead end', () => {
    component.control = {
      ...component.control,
      loading: false,
      cropName: 'Tomato',
      jsonInput: '{not-json'
    };
    fixture.detectChanges();

    component.previewProposal();
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('Invalid JSON.');
    expect(fixture.nativeElement.textContent).toContain('Fix the JSON above and run Preview again.');
    expect(fixture.nativeElement.querySelector('#proposal-json')).toBeTruthy();
  });

  it('apply validation failure does not navigate to crop stages', () => {
    component.control = {
      ...component.control,
      loading: false,
      cropName: 'Tomato',
      jsonInput: JSON.stringify(validProposal),
      phase: 'preview',
      normalizedPreview: validProposal,
      parsedProposal: validProposal
    };
    fixture.detectChanges();

    component.applyProposal();

    presenter.onApplySuccess({
      mode: 'apply',
      valid: false,
      errors: [{ path: 'stages[0].order', message: 'conflicts with an existing crop stage order' }]
    });
    fixture.detectChanges();

    expect(mockApplyUseCase.execute).toHaveBeenCalled();
    expect(component.control.phase).toBe('validation_errors');
    expect(component.control.validationErrors[0]?.path).toBe('stages[0].order');
  });

  it('apply uses current textarea JSON instead of stale parsedProposal', () => {
    const updatedProposal = {
      ...validProposal,
      stages: [{ name: '定植', order: 2, thermal_requirement: { required_gdd: '200' } }]
    };
    component.control = {
      ...component.control,
      loading: false,
      cropName: 'Tomato',
      jsonInput: JSON.stringify(updatedProposal),
      phase: 'preview',
      normalizedPreview: validProposal,
      parsedProposal: validProposal
    };
    fixture.detectChanges();

    component.applyProposal();

    expect(mockApplyUseCase.execute).toHaveBeenCalledWith(
      expect.objectContaining({ cropId: 42, proposal: updatedProposal })
    );
  });

  it('apply success shows crop detail CTA instead of auto-navigating', () => {
    component.control = {
      ...component.control,
      loading: false,
      cropName: 'Tomato',
      jsonInput: JSON.stringify(validProposal),
      phase: 'preview',
      normalizedPreview: validProposal,
      parsedProposal: validProposal
    };
    fixture.detectChanges();

    component.applyProposal();

    expect(mockApplyUseCase.execute).toHaveBeenCalledWith(
      expect.objectContaining({ cropId: 42, proposal: validProposal })
    );

    const onSuccess = mockApplyUseCase.execute.mock.calls[0][0].onSuccess as () => void;
    presenter.onApplySuccess({
      mode: 'apply',
      valid: true,
      normalized: validProposal,
      result: { stage_ids: [1], agricultural_task_ids: [2], blueprint_ids: [3] }
    });
    onSuccess();
    fixture.detectChanges();

    expect(component.control.phase).toBe('success');
    const backLink = fixture.nativeElement.querySelector(
      'a.crop-setup-proposal-import__back-to-crop'
    );
    expect(backLink).toBeTruthy();
    expect(backLink.getAttribute('href')).toBe('/crops/42');
    expect(fixture.nativeElement.textContent).toContain('Proposal applied');
  });

  it('navigates to learn post_master after apply success when returnTo=learn', () => {
    component.fromPlanId = 7;
    component.returnTab = 'learn';
    storeLearnBpTimingApplyContext(42, {
      planId: 7,
      cropId: 42,
      cropName: 'Tomato',
      category: 'general'
    });
    component.control = {
      ...component.control,
      loading: false,
      cropName: 'Tomato',
      jsonInput: JSON.stringify(validProposal),
      phase: 'preview',
      normalizedPreview: validProposal,
      parsedProposal: validProposal
    };
    fixture.detectChanges();

    component.applyProposal();

    const onSuccess = mockApplyUseCase.execute.mock.calls[0][0].onSuccess as () => void;
    presenter.onApplySuccess({
      mode: 'apply',
      valid: true,
      normalized: validProposal,
      result: { stage_ids: [1], agricultural_task_ids: [2], blueprint_ids: [3] }
    });
    onSuccess();
    fixture.detectChanges();

    expect(mockRouter.navigate).toHaveBeenCalledWith(['/plans', 7, 'learn'], {
      queryParams: { followUp: 'post_master' }
    });
  });
});
