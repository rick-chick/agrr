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
  undo_path: '/undo_deletion?undo_token=token123',
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
          agricultural_task_id: null
        },
        fieldOptions: [],
        showDetails: false,
        taskChips: [],
        loadingTaskChips: false,
        selectedTaskId: null,
        pendingToastKey: null,
        pendingUndoToast: null,
        existingPhotos: [],
        pendingPhotos: [],
        photoError: null
      },
      close: vi.fn()
    };
    presenter.setView(view);
    presenter.onSavedCallback = onSavedCallback as (event: WorkRecordSheetSavedEvent) => void;
    presenter.onDeletedCallback = onDeletedCallback as () => void;
  });

  it('queues ad-hoc toast and emits saved payload on create success', () => {
    presenter.onSuccess({ workRecord });

    expect(view.control.pendingToastKey).toBe('plans.work.toast.record_saved_adhoc');
    expect(view.close).toHaveBeenCalled();
    expect(onSavedCallback).toHaveBeenCalledWith({
      workRecord,
      mode: 'create-adhoc'
    });
  });

  it('queues schedule toast on create-from-item success', () => {
    view.control = { ...view.control, mode: 'create-from-item' };

    presenter.onSuccess({
      workRecord: { ...workRecord, task_schedule_item_id: 5 }
    });

    expect(view.control.pendingToastKey).toBe('plans.work.toast.record_saved');
    expect(onSavedCallback).toHaveBeenCalledWith(
      expect.objectContaining({ mode: 'create-from-item' })
    );
  });

  it('queues updated toast on edit success', () => {
    view.control = { ...view.control, mode: 'edit' };

    presenter.onSuccess({ workRecord });

    expect(view.control.pendingToastKey).toBe('plans.work_records.toast.record_updated');
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
});
