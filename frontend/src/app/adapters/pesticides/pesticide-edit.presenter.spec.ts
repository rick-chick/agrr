import { TestBed } from '@angular/core/testing';
import { PesticideEditPresenter } from './pesticide-edit.presenter';
import {
  PesticideEditView,
  PesticideEditViewState
} from '../../components/masters/pesticides/pesticide-edit.view';

describe('PesticideEditPresenter', () => {
  let presenter: PesticideEditPresenter;
  let lastControl: PesticideEditViewState | null;

  const emptyFormData: PesticideEditViewState['formData'] = {
    name: '',
    active_ingredient: null,
    description: null,
    crop_id: 0,
    pest_id: 0,
    region: null
  };

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [PesticideEditPresenter]
    });
    presenter = TestBed.inject(PesticideEditPresenter);
    lastControl = null;
    const view: PesticideEditView = {
      get control(): PesticideEditViewState {
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
      set control(value: PesticideEditViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  it('maps raw HTTP 500 text to i18n key on onError(dto)', () => {
    lastControl = {
      loading: true,
      saving: false,
      error: null,
      pendingErrorFlash: null,
      formData: emptyFormData
    };

    presenter.onError({
      message:
        'Http failure response for https://agrr.local/api/v1/masters/pesticides/1: 500 Internal Server Error'
    });

    expect(lastControl!.error).toBe('common.api_error.generic');
    expect(lastControl!.error).not.toContain('Http failure');
    expect(lastControl!.loading).toBe(false);
  });
});
