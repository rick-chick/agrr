import { describe, it, expect, beforeEach } from 'vitest';
import { BACKEND_WARMUP_I18N } from '../../core/backend-warmup/backend-warmup';
import {
  EntryScheduleFarmCropsView,
  EntryScheduleFarmCropsViewState
} from '../../components/entry-schedule/entry-schedule-farm-crops.view';
import { EntryScheduleFarmCropsPresenter } from './entry-schedule-farm-crops.presenter';

describe('EntryScheduleFarmCropsPresenter', () => {
  let presenter: EntryScheduleFarmCropsPresenter;
  let lastControl: EntryScheduleFarmCropsViewState;

  const baseControl: EntryScheduleFarmCropsViewState = {
    farmLoading: false,
    selectedFarmId: 1,
    selectedFarm: { id: 1, name: 'Farm', latitude: 35, longitude: 139, region: 'jp' },
    listResponse: null,
    cropsLoading: true,
    cropsError: null,
    cropsErrorIsWarmup: false,
    cropsWarmupMessageKey: null,
    loadCursor: null
  };

  const view: EntryScheduleFarmCropsView = {
    get control() {
      return lastControl;
    },
    set control(value) {
      lastControl = value;
    },
    afterFarmResolved: () => {},
    onInvalidFarm: () => {}
  };

  beforeEach(() => {
    presenter = new EntryScheduleFarmCropsPresenter();
    lastControl = { ...baseControl };
    presenter.setView(view);
  });

  it('sets cropsErrorIsWarmup true on warmup load failure', () => {
    presenter.onError({
      message:
        'Http failure response for https://agrr.local/api/v1/entry_schedule/farms/1/crops: 503 Service Unavailable'
    });

    expect(lastControl.cropsError).toBe(BACKEND_WARMUP_I18N.database);
    expect(lastControl.cropsErrorIsWarmup).toBe(true);
    expect(lastControl.cropsWarmupMessageKey).toBe(BACKEND_WARMUP_I18N.database);
    expect(lastControl.cropsLoading).toBe(false);
  });
});
