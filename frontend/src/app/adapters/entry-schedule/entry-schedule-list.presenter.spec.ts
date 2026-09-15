import { describe, it, expect, beforeEach } from 'vitest';
import { BACKEND_WARMUP_I18N } from '../../core/backend-warmup/backend-warmup';
import { EntryScheduleListView, EntryScheduleListViewState } from '../../components/entry-schedule/entry-schedule-list.view';
import { EntryScheduleListPresenter } from './entry-schedule-list.presenter';

describe('EntryScheduleListPresenter', () => {
  let presenter: EntryScheduleListPresenter;
  let lastControl: EntryScheduleListViewState;

  const baseControl: EntryScheduleListViewState = {
    farmsLoading: true,
    farmsError: null,
    farmsErrorIsWarmup: false,
    farmsWarmupMessageKey: null,
    farms: []
  };

  const view: EntryScheduleListView = {
    get control() {
      return lastControl;
    },
    set control(value) {
      lastControl = value;
    }
  };

  beforeEach(() => {
    presenter = new EntryScheduleListPresenter();
    lastControl = { ...baseControl };
    presenter.setView(view);
  });

  it('sets farmsErrorIsWarmup true on warmup load failure', () => {
    presenter.onError({
      message:
        'Http failure response for https://agrr.local/api/v1/entry_schedule/farms: 503 Service Unavailable'
    });

    expect(lastControl.farmsError).toBe(BACKEND_WARMUP_I18N.database);
    expect(lastControl.farmsErrorIsWarmup).toBe(true);
    expect(lastControl.farmsWarmupMessageKey).toBe(BACKEND_WARMUP_I18N.database);
    expect(lastControl.farmsLoading).toBe(false);
    expect(lastControl.farms).toEqual([]);
  });
});
