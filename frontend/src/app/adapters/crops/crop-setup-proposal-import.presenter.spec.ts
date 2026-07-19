import { TestBed } from '@angular/core/testing';
import { describe, it, expect, beforeEach } from 'vitest';
import { CropSetupProposalImportPresenter } from './crop-setup-proposal-import.presenter';
import {
  CropSetupProposalImportView,
  CropSetupProposalImportViewState
} from '../../components/masters/crops/crop-setup-proposal-import.view';

const initialControl: CropSetupProposalImportViewState = {
  loading: true,
  submitting: false,
  applying: false,
  error: null,
  cropName: null,
  jsonInput: '',
  phase: 'input',
  validationErrors: [],
  normalizedPreview: null,
  parsedProposal: null
};

const validProposal = {
  stages: [{ name: '育苗', order: 1, thermal_requirement: { required_gdd: '120' } }],
  agricultural_tasks: [{ ref: 'task-weeding', name: '除草', task_type: 'field_work', region: 'jp' }],
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

describe('CropSetupProposalImportPresenter', () => {
  let presenter: CropSetupProposalImportPresenter;
  let lastControl: CropSetupProposalImportViewState;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [CropSetupProposalImportPresenter]
    });
    presenter = TestBed.inject(CropSetupProposalImportPresenter);
    lastControl = { ...initialControl };
    const view: CropSetupProposalImportView = {
      get control(): CropSetupProposalImportViewState {
        return lastControl;
      },
      set control(value: CropSetupProposalImportViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  it('presents crop name after load', () => {
    presenter.present({ crop: { id: 42, name: 'Tomato' } as never });

    expect(lastControl.loading).toBe(false);
    expect(lastControl.error).toBeNull();
    expect(lastControl.cropName).toBe('Tomato');
  });

  it('onDryRunStarted clears prior preview and validation errors', () => {
    lastControl = {
      ...initialControl,
      loading: false,
      phase: 'validation_errors',
      validationErrors: [{ path: 'stages', message: 'invalid' }],
      normalizedPreview: validProposal
    };

    presenter.onDryRunStarted();

    expect(lastControl.submitting).toBe(true);
    expect(lastControl.phase).toBe('input');
    expect(lastControl.validationErrors).toEqual([]);
    expect(lastControl.normalizedPreview).toBeNull();
  });

  it('onDryRunSuccess with valid response moves to preview phase', () => {
    presenter.onDryRunSuccess({
      mode: 'dry_run',
      valid: true,
      normalized: validProposal
    });

    expect(lastControl.submitting).toBe(false);
    expect(lastControl.phase).toBe('preview');
    expect(lastControl.normalizedPreview).toEqual(validProposal);
  });

  it('onDryRunSuccess with invalid response shows validation errors', () => {
    presenter.onDryRunSuccess({
      mode: 'dry_run',
      valid: false,
      errors: [{ path: 'stages[0].name', message: 'is required' }]
    });

    expect(lastControl.submitting).toBe(false);
    expect(lastControl.phase).toBe('validation_errors');
    expect(lastControl.validationErrors).toEqual([
      { path: 'stages[0].name', message: 'is required' }
    ]);
    expect(lastControl.normalizedPreview).toBeNull();
  });

  it('onApplyStarted and onApplySuccess toggle applying flag', () => {
    presenter.onApplyStarted();
    expect(lastControl.applying).toBe(true);
    expect(lastControl.error).toBeNull();

    presenter.onApplySuccess({
      mode: 'apply',
      valid: true,
      normalized: validProposal,
      result: { stage_ids: [1], agricultural_task_ids: [2], blueprint_ids: [3] }
    });
    expect(lastControl.applying).toBe(false);
  });

  it('onError clears loading and submitting flags', () => {
    lastControl = {
      ...initialControl,
      loading: true,
      submitting: true,
      applying: true
    };

    presenter.onError({ message: 'crops.setup_proposal_import.apply_failed' });

    expect(lastControl.loading).toBe(false);
    expect(lastControl.submitting).toBe(false);
    expect(lastControl.applying).toBe(false);
    expect(lastControl.error).toBe('crops.setup_proposal_import.apply_failed');
  });
});
