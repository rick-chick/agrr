import { TestBed } from '@angular/core/testing';
import { PestEditPresenter } from './pest-edit.presenter';
import { PestEditView, PestEditViewState } from '../../components/masters/pests/pest-edit.view';

describe('PestEditPresenter', () => {
  let presenter: PestEditPresenter;
  let lastControl: PestEditViewState | null;

  const emptyFormData: PestEditViewState['formData'] = {
    name: '',
    name_scientific: null,
    family: null,
    order: null,
    description: null,
    occurrence_season: null,
    region: null
  };

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [PestEditPresenter]
    });
    presenter = TestBed.inject(PestEditPresenter);
    lastControl = null;
    const view: PestEditView = {
      get control(): PestEditViewState {
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
      set control(value: PestEditViewState) {
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
      message: 'Http failure response for https://agrr.local/api/v1/masters/pests/1: 404 Not Found'
    });

    expect(lastControl!.error).toBe('common.api_error.not_found');
    expect(lastControl!.error).not.toContain('Http failure');
    expect(lastControl!.loading).toBe(false);
  });
});
