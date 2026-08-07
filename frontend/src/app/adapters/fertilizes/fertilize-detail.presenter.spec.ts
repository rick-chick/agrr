import { TestBed } from '@angular/core/testing';
import { FertilizeDetailPresenter } from './fertilize-detail.presenter';
import {
  FertilizeDetailView,
  FertilizeDetailViewState
} from '../../components/masters/fertilizes/fertilize-detail.view';

describe('FertilizeDetailPresenter', () => {
  let presenter: FertilizeDetailPresenter;
  let lastControl: FertilizeDetailViewState | null;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [FertilizeDetailPresenter]
    });
    presenter = TestBed.inject(FertilizeDetailPresenter);
    lastControl = null;
    const view: FertilizeDetailView = {
      get control(): FertilizeDetailViewState {
        return (
          lastControl ?? {
            loading: true,
            error: null,
            fertilize: null,
            pendingErrorFlash: null
          }
        );
      },
      set control(value: FertilizeDetailViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  it('sets inline error key on onError(dto)', () => {
    lastControl = { loading: true, error: null, fertilize: null, pendingErrorFlash: null };

    presenter.onError({ message: 'common.api_error.not_found' });

    expect(lastControl!.error).toBe('common.api_error.not_found');
    expect(lastControl!.loading).toBe(false);
  });

  it('maps raw HTTP error text to i18n key on onError(dto)', () => {
    lastControl = { loading: true, error: null, fertilize: null, pendingErrorFlash: null };

    presenter.onError({
      message:
        'Http failure response for https://agrr.local/api/v1/masters/fertilizes/999: 404 Not Found'
    });

    expect(lastControl!.error).toBe('common.api_error.not_found');
    expect(lastControl!.error).not.toContain('Http failure');
  });
});
