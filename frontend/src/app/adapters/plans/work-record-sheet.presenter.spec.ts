import { TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { WorkRecordSheetSavedEvent, WorkRecordSheetView } from '../../components/plans/work-record-sheet.view';
import { WorkRecord } from '../../models/plans/work-record';
import { UndoToastService } from '../../services/undo-toast.service';
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

describe('WorkRecordSheetPresenter', () => {
  let presenter: WorkRecordSheetPresenter;
  let view: WorkRecordSheetView;
  let toastShow: ReturnType<typeof vi.fn>;
  let onSavedCallback: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    toastShow = vi.fn();
    onSavedCallback = vi.fn();

    TestBed.configureTestingModule({
      imports: [TranslateModule.forRoot()],
      providers: [
        WorkRecordSheetPresenter,
        { provide: UndoToastService, useValue: { show: toastShow } }
      ]
    });

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'ja',
      {
        'plans.work.toast.record_saved': '作業を記録しました',
        'plans.work.toast.record_saved_adhoc': '作業を記録しました。実績履歴で確認できます',
        'plans.work_records.toast.record_updated': '実績を保存しました',
        'plans.work_records.toast.record_deleted': '実績を削除しました'
      },
      true
    );
    translate.use('ja');

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
        selectedTaskId: null
      },
      close: vi.fn()
    };
    presenter.setView(view);
    presenter.onSavedCallback = onSavedCallback as (event: WorkRecordSheetSavedEvent) => void;
  });

  it('shows ad-hoc toast and emits saved payload on create success', () => {
    presenter.onSuccess({ workRecord });

    expect(toastShow).toHaveBeenCalledWith('作業を記録しました。実績履歴で確認できます');
    expect(view.close).toHaveBeenCalled();
    expect(onSavedCallback).toHaveBeenCalledWith({
      workRecord,
      mode: 'create-adhoc'
    });
  });

  it('shows schedule toast on create-from-item success', () => {
    view.control = { ...view.control, mode: 'create-from-item' };

    presenter.onSuccess({
      workRecord: { ...workRecord, task_schedule_item_id: 5 }
    });

    expect(toastShow).toHaveBeenCalledWith('作業を記録しました');
    expect(onSavedCallback).toHaveBeenCalledWith(
      expect.objectContaining({ mode: 'create-from-item' })
    );
  });

  it('shows updated toast on edit success', () => {
    view.control = { ...view.control, mode: 'edit' };

    presenter.onSuccess({ workRecord });

    expect(toastShow).toHaveBeenCalledWith('実績を保存しました');
  });

  it('shows deleted toast on delete success', () => {
    presenter.onDeleteSuccess();

    expect(toastShow).toHaveBeenCalledWith('実績を削除しました');
    expect(view.close).toHaveBeenCalled();
  });
});
