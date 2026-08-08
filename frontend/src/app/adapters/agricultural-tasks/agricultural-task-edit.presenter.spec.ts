import { TestBed } from '@angular/core/testing';
import { AgriculturalTaskEditPresenter } from './agricultural-task-edit.presenter';
import {
  AgriculturalTaskEditView,
  AgriculturalTaskEditViewState
} from '../../components/masters/agricultural-tasks/agricultural-task-edit.view';

describe('AgriculturalTaskEditPresenter', () => {
  let presenter: AgriculturalTaskEditPresenter;
  let lastControl: AgriculturalTaskEditViewState | null;

  const emptyFormData: AgriculturalTaskEditViewState['formData'] = {
    name: '',
    description: null,
    time_per_sqm: null,
    weather_dependency: undefined,
    required_tools: [],
    skill_level: undefined,
    region: null,
    task_type: null
  };

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [AgriculturalTaskEditPresenter]
    });
    presenter = TestBed.inject(AgriculturalTaskEditPresenter);
    lastControl = null;
    const view: AgriculturalTaskEditView = {
      get control(): AgriculturalTaskEditViewState {
        return (
          lastControl ?? {
            loading: true,
            saving: false,
            error: null,
            pendingErrorFlash: null,
            formData: emptyFormData
          }
        );
      },
      set control(value: AgriculturalTaskEditViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  it('maps raw HTTP 404 text to i18n key on onError(dto)', () => {
    lastControl = {
      loading: true,
      saving: false,
      error: null,
      pendingErrorFlash: null,
      formData: emptyFormData
    };

    presenter.onError({
      message:
        'Http failure response for https://agrr.local/api/v1/masters/agricultural_tasks/1: 404 Not Found'
    });

    expect(lastControl!.error).toBe('common.api_error.not_found');
    expect(lastControl!.error).not.toContain('Http failure');
    expect(lastControl!.loading).toBe(false);
  });
});
