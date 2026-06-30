import { TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PlanWorkView } from '../../components/plans/plan-work.view';
import { WorkRecordSheetSavedEvent } from '../../components/plans/work-record-sheet.view';
import { WorkRecord } from '../../models/plans/work-record';
import { UndoToastService } from '../../services/undo-toast.service';
import { PlanWorkPresenter } from './plan-work.presenter';

const workRecord: WorkRecord = {
  id: 1,
  cultivation_plan_id: 7,
  field_cultivation_id: 10,
  task_schedule_item_id: 11,
  agricultural_task_id: null,
  name: '追肥',
  task_type: null,
  actual_date: '2026-06-25',
  amount: null,
  amount_unit: null,
  time_spent_minutes: null,
  notes: null,
  created_at: '2026-06-25',
  updated_at: '2026-06-25',
  task_schedule_item: null
};

describe('PlanWorkPresenter quick complete', () => {
  let presenter: PlanWorkPresenter;
  let view: PlanWorkView;
  let toastShow: ReturnType<typeof vi.fn>;
  let onRecordSavedCallback: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    toastShow = vi.fn();
    onRecordSavedCallback = vi.fn();

    TestBed.configureTestingModule({
      imports: [TranslateModule.forRoot()],
      providers: [
        PlanWorkPresenter,
        { provide: UndoToastService, useValue: { show: toastShow } }
      ]
    });

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('ja', { 'plans.work.toast.record_saved': '作業を記録しました' }, true);
    translate.use('ja');

    presenter = TestBed.inject(PlanWorkPresenter);
    view = {
      control: {
        loading: false,
        error: null,
        plan: null,
        fields: [],
        overdue: [],
        today: [],
        upcoming: [],
        includeSkipped: false,
        recentAdHocRecord: null,
        highlightedItemId: null,
        completingItemId: 11
      }
    };
    presenter.setView(view);
    presenter.onRecordSavedCallback = onRecordSavedCallback as (event: WorkRecordSheetSavedEvent) => void;
  });

  it('shows toast and emits saved event on quick complete success', () => {
    presenter.onSuccess({ workRecord });

    expect(toastShow).toHaveBeenCalledWith('作業を記録しました');
    expect(onRecordSavedCallback).toHaveBeenCalledWith({
      workRecord,
      mode: 'create-from-item'
    });
    expect(view.control.completingItemId).toBeNull();
  });

  it('clears completingItemId on quick complete error', () => {
    presenter.onError({ message: 'common.api_error.generic' });

    expect(view.control.completingItemId).toBeNull();
    expect(view.control.error).toBe('common.api_error.generic');
  });
});
