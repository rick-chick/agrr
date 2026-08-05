import { TestBed } from '@angular/core/testing';
import { describe, expect, it, beforeEach } from 'vitest';
import { CropDetailPresenter } from './crop-detail.presenter';
import { CropDetailView, CropDetailViewState } from '../../components/masters/crops/crop-detail.view';
import { ListRefreshBus } from '../../core/list-refresh/list-refresh-bus.service';
import {
  defaultBlueprintReadiness,
  withCropDetailSummaryState
} from './crop-detail-presenter.helpers';

const baseControl: CropDetailViewState = withCropDetailSummaryState({
  loading: false,
  error: null,
  crop: { id: 3, name: 'Tomato', is_reference: false, groups: [] },
  pendingUndoToast: null,
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  blueprintsLoading: false,
  blueprintCount: 0,
  blueprintReadiness: defaultBlueprintReadiness(),
  blueprintSummary: null,
  stageBoardColumns: [],
  cumulativeGddTimelineSegments: []
});

describe('CropDetailPresenter', () => {
  let presenter: CropDetailPresenter;
  let lastControl: CropDetailViewState;
  let view: CropDetailView;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [CropDetailPresenter, { provide: ListRefreshBus, useValue: { refresh: () => {} } }]
    });
    presenter = TestBed.inject(CropDetailPresenter);
    lastControl = { ...baseControl };
    view = {
      get control(): CropDetailViewState {
        return lastControl;
      },
      set control(value: CropDetailViewState) {
        lastControl = value;
      },
      reload: () => {}
    };
    presenter.setView(view);
  });

  it('presents crop detail', () => {
    presenter.present({
      crop: { id: 3, name: 'Tomato', is_reference: false, groups: [] }
    });

    expect(lastControl.loading).toBe(false);
    expect(lastControl.crop?.name).toBe('Tomato');
  });

  it('presents blueprint summary from blueprint list', () => {
    presenter.present({
      blueprints: [
        {
          id: 1,
          crop_id: 3,
          agricultural_task_id: 5,
          source_agricultural_task_id: null,
          stage_order: 1,
          stage_name: 'Vegetative',
          gdd_trigger: 100,
          gdd_tolerance: null,
          task_type: 'field_work',
          source: 'agrr',
          priority: 1,
          amount: null,
          amount_unit: null,
          description: null,
          weather_dependency: null,
          time_per_sqm: null
        }
      ]
    });

    expect(lastControl.blueprintsLoading).toBe(false);
    expect(lastControl.blueprintCount).toBe(1);
  });

  it('shows inline load error when loading fails', () => {
    lastControl = { ...baseControl, loading: true, blueprintsLoading: true };

    presenter.onError({ message: 'common.api_error.not_found' });

    expect(lastControl.error).toBe('common.api_error.not_found');
    expect(lastControl.pendingErrorFlash).toBeNull();
    expect(lastControl.loading).toBe(false);
    expect(lastControl.blueprintsLoading).toBe(false);
  });

  it('maps raw HTTP 404 text to i18n key on initial load failure', () => {
    lastControl = { ...baseControl, loading: true, blueprintsLoading: true };

    presenter.onError({
      message: 'Http failure response for https://agrr.local/api/v1/masters/crops/999: 404 Not Found'
    });

    expect(lastControl.error).toBe('common.api_error.not_found');
    expect(lastControl.error).not.toContain('Http failure');
  });

  it('uses flash for errors after load completes', () => {
    lastControl = { ...baseControl, loading: false, blueprintsLoading: false };

    presenter.onError({ message: 'common.api_error.generic' });

    expect(lastControl.pendingErrorFlash).toEqual({
      type: 'error',
      text: 'common.api_error.generic'
    });
    expect(lastControl.error).toBeNull();
    expect(lastControl.loading).toBe(false);
    expect(lastControl.blueprintsLoading).toBe(false);
  });
});
