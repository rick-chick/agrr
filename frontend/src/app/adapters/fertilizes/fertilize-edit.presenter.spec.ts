import { TestBed } from '@angular/core/testing';
import { FertilizeEditPresenter } from './fertilize-edit.presenter';
import {
  FertilizeEditView,
  FertilizeEditViewState
} from '../../components/masters/fertilizes/fertilize-edit.view';

describe('FertilizeEditPresenter', () => {
  let presenter: FertilizeEditPresenter;
  let lastControl: FertilizeEditViewState | null;

  const emptyFormData: FertilizeEditViewState['formData'] = {
    name: '',
    n: null,
    p: null,
    k: null,
    description: null,
    package_size: null,
    region: null
  };

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [FertilizeEditPresenter]
    });
    presenter = TestBed.inject(FertilizeEditPresenter);
    lastControl = null;
    const view: FertilizeEditView = {
      get control(): FertilizeEditViewState {
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
      set control(value: FertilizeEditViewState) {
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
        'Http failure response for https://agrr.local/api/v1/masters/fertilizes/1: 404 Not Found'
    });

    expect(lastControl!.error).toBe('common.api_error.not_found');
    expect(lastControl!.error).not.toContain('Http failure');
    expect(lastControl!.loading).toBe(false);
  });
});
