import { TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { WorkRecordSheetSavedEvent, WorkRecordSheetView } from '../../components/plans/work-record-sheet.view';
import { WorkRecord } from '../../models/plans/work-record';
import { WorkRecordSheetPresenter } from './work-record-sheet.presenter';

const workRecord: WorkRecord = {
  id: 42,
  cultivation_plan_id: 7,
  field_cultivation_id: 10,
  task_schedule_item_id: null,
  agricultural_task_id: null,
  name: '除草',
  task_type: null,
  actual_date: '2026-06-26',
  amount: null,
  amount_unit: null,
  time_spent_minutes: null,
  notes: null,
  created_at: '2026-06-26',
  updated_at: '2026-06-26',
  task_schedule_item: null
};

const undoResponse = {
  undo_token: 'token123',
  undo_path: '/undo_deletion',
  toast_message: 'plans.work_records.undo.toast:除草',
  undo_deadline: '2026-02-03T12:00:00Z',
  auto_hide_after: 5000
};

describe('WorkRecordSheetPresenter', () => {
  let presenter: WorkRecordSheetPresenter;
  let view: WorkRecordSheetView;
  let onSavedCallback: ReturnType<typeof vi.fn>;
  let onDeletedCallback: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    onSavedCallback = vi.fn();
    onDeletedCallback = vi.fn();

    TestBed.configureTestingModule({
      providers: [WorkRecordSheetPresenter]
    });

    presenter = TestBed.inject(WorkRecordSheetPresenter);
    view = {
      control: {
        mode: 'create-adhoc',
        submitting: true,
        error: null,
        fieldErrors: {},
        form: {
          name: '除草',
          actual_date: '2026-06-26',
          amount: '',
          amount_unit: '',
          time_spent_minutes: '',
          notes: '',
          field_cultivation_id: null,
          fieldName: '',
          cropName: '',
          task_schedule_item_id: null,
          work_record_id: null,
          agricultural_task_id: null,
          fertilize_id: null,
          pesticide_id: null
        },
        fieldOptions: [],
        scheduleCategory: null,
        cropId: null,
        fertilizeOptions: [],
        pesticideOptions: [],
        loadingFertilizeOptions: false,
        loadingPesticideOptions: false,
        harvestContext: false,
        plannedAmount: '',
        plannedAmountUnit: '',
        climatePreview: {
          gddAtActual: null,
          weatherDate: null,
          temperatureMax: null,
          temperatureMin: null,
          temperatureMean: null,
          plannedGdd: null,
          gddDelta: null,
          loading: false
        },
        showDetails: false,
        taskChips: [],
        loadingTaskChips: false,
        selectedTaskId: null,
        pendingToast: null,
        saveToastContext: null,
        pendingUndoToast: null,
        existingPhotos: [],
        pendingPhotos: [],
        photoError: null,
        pendingPhotoResyncWorkRecord: null
      },
      close: vi.fn()
    };
    presenter.setView(view);
    presenter.onSavedCallback = onSavedCallback as (event: WorkRecordSheetSavedEvent) => void;
    presenter.onDeletedCallback = onDeletedCallback as () => void;
  });

  it('queues ad-hoc toast and emits saved payload on create success', () => {
    presenter.onSuccess({ workRecord, mode: 'create-adhoc' });

    expect(view.control.pendingToast).toEqual({
      textKey: 'plans.work.toast.record_saved_adhoc'
    });
    expect(view.close).toHaveBeenCalled();
    expect(onSavedCallback).toHaveBeenCalledWith({
      workRecord,
      mode: 'create-adhoc',
      saveToastContext: null
    });
  });

  it('queues variance toast on create-from-item success', () => {
    view.control = {
      ...view.control,
      mode: 'create-from-item',
      saveToastContext: {
        planId: 7,
        fieldCultivationId: 10,
        taskScheduleItemId: 5,
        gddTrigger: 100
      }
    };

    presenter.onSuccess({
      workRecord: {
        ...workRecord,
        task_schedule_item_id: 5,
        gdd_at_actual: 130.5,
        task_schedule_item: { id: 5, name: '除草', scheduled_date: '2026-06-10' },
        actual_date: '2026-06-13'
      },
      mode: 'create-from-item'
    });

    expect(view.control.pendingToast).toEqual({
      textKey: 'plans.work.toast.record_saved_variance',
      textParams: {
        name: '除草',
        deltaDays: '+3',
        gddDelta: '+30.5'
      },
      action: {
        labelKey: 'plans.work.toast.view_task_detail',
        routerLink: ['/plans', 7, 'task_schedule'],
        queryParams: {
          field_cultivation_id: 10,
          item_id: 5
        }
      }
    });
  });

  it('queues updated toast on edit success', () => {
    view.control = { ...view.control, mode: 'edit' };

    presenter.onSuccess({ workRecord, mode: 'edit' });

    expect(view.control.pendingToast).toEqual({
      textKey: 'plans.work_records.toast.record_updated'
    });
  });

  it('queues undo toast on delete success', () => {
    presenter.onDeleteSuccess({ undo: undoResponse });

    expect(view.control.pendingUndoToast).toEqual({
      message: undoResponse.toast_message,
      undoPath: undoResponse.undo_path,
      undoToken: undoResponse.undo_token,
      onRestored: expect.any(Function),
      resourceLabel: undefined
    });
    expect(view.close).toHaveBeenCalled();
    expect(onDeletedCallback).toHaveBeenCalled();
  });

  it('maps planned GDD comparison fields in presentClimatePreview', () => {
    presenter.presentClimatePreview({
      gddAtActual: 145.25,
      weatherDate: '2026-06-12',
      temperatureMax: 30,
      temperatureMin: 20,
      temperatureMean: 25,
      plannedGdd: 100,
      gddDelta: 45.3,
      loading: false
    });

    expect(view.control.climatePreview).toEqual({
      gddAtActual: 145.25,
      weatherDate: '2026-06-12',
      temperatureMax: 30,
      temperatureMin: 20,
      temperatureMean: 25,
      plannedGdd: 100,
      gddDelta: 45.3,
      loading: false
    });
  });

  it('resyncs photos and shows partial failure message', () => {
    const reloaded: WorkRecord = {
      ...workRecord,
      photos: [
        {
          id: 3,
          work_record_id: 42,
          position: 0,
          content_type: 'image/jpeg',
          byte_size: 10,
          url: '/photos/3.jpg',
          created_at: '2026-06-26'
        }
      ]
    };

    presenter.onPhotoPartialFailure({ workRecord: reloaded });

    expect(view.control.submitting).toBe(false);
    expect(view.control.photoError).toBe('plans.work.sheet.photos.errors.partial_sync_failed');
    expect(view.control.pendingPhotoResyncWorkRecord).toEqual(reloaded);
    expect(view.close).not.toHaveBeenCalled();
  });
});
