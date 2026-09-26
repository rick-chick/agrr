import { describe, it, expect, beforeEach } from 'vitest';
import { BACKEND_WARMUP_I18N } from '../../core/backend-warmup/backend-warmup';
import { EntryScheduleDetailView, EntryScheduleDetailViewState } from '../../components/entry-schedule/entry-schedule-detail.view';
import { EntryScheduleDetailPresenter } from './entry-schedule-detail.presenter';

describe('EntryScheduleDetailPresenter', () => {
  let presenter: EntryScheduleDetailPresenter;
  let lastControl: EntryScheduleDetailViewState;

  const baseControl: EntryScheduleDetailViewState = {
    loading: true,
    errorKey: null,
    errorIsWarmup: false,
    warmupMessageKey: null,
    data: null
  };

  const view: EntryScheduleDetailView = {
    get control() {
      return lastControl;
    },
    set control(value) {
      lastControl = value;
    },
    onCropLoaded: () => {},
    onCropLoadFailed: () => {}
  };

  beforeEach(() => {
    presenter = new EntryScheduleDetailPresenter();
    lastControl = { ...baseControl };
    presenter.setView(view);
  });

  it('sets errorIsWarmup true on warmup load failure', () => {
    presenter.onError({
      message:
        'Http failure response for https://agrr.local/api/v1/entry_schedule/farms/1/crops/3: 503 Service Unavailable'
    });

    expect(lastControl.errorKey).toBe(BACKEND_WARMUP_I18N.database);
    expect(lastControl.errorIsWarmup).toBe(true);
    expect(lastControl.warmupMessageKey).toBe(BACKEND_WARMUP_I18N.database);
    expect(lastControl.loading).toBe(false);
  });

  it('maps generic API errors without warmup flag', () => {
    presenter.onError({ message: 'common.api_error.generic' });

    expect(lastControl.errorKey).toBe('common.api_error.generic');
    expect(lastControl.errorIsWarmup).toBe(false);
    expect(lastControl.warmupMessageKey).toBeNull();
  });

  it('sets errorIsWarmup false on entry-schedule prediction failure', () => {
    presenter.onError({ message: 'api.entry_schedule.errors.prediction_failed' });

    expect(lastControl.errorKey).toBe('api.entry_schedule.errors.prediction_failed');
    expect(lastControl.errorIsWarmup).toBe(false);
    expect(lastControl.warmupMessageKey).toBeNull();
    expect(lastControl.loading).toBe(false);
  });

  it('sets errorIsWarmup false on weather_location_required', () => {
    presenter.onError({ message: 'api.entry_schedule.errors.weather_location_required' });

    expect(lastControl.errorKey).toBe('api.entry_schedule.errors.weather_location_required');
    expect(lastControl.errorIsWarmup).toBe(false);
    expect(lastControl.warmupMessageKey).toBeNull();
    expect(lastControl.loading).toBe(false);
  });
});
