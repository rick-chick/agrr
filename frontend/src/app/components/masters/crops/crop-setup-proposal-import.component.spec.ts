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
      clipboard_error: 'Could not read clipboard.'
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
  let router: Router;

  beforeEach(async () => {
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
            snapshot: { paramMap: convertToParamMap({ id: '42' }) },
            paramMap: of(convertToParamMap({ id: '42' }))
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

    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigate').mockResolvedValue(true);

    fixture = TestBed.createComponent(CropSetupProposalImportComponent);
    component = fixture.componentInstance;
    presenter = fixture.debugElement.injector.get(CropSetupProposalImportPresenter);
    fixture.detectChanges();
  });

  it('should create and load crop on init', () => {
    expect(component).toBeTruthy();
    expect(mockLoadUseCase.execute).toHaveBeenCalledWith({ cropId: 42 });
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
    expect(fixture.nativeElement.textContent).toContain('is required');
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

    expect(router.navigate).not.toHaveBeenCalled();
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

  it('apply success navigates to crop stages', () => {
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
    expect(router.navigate).toHaveBeenCalledWith(['/crops', 42, 'stages']);
  });
});
