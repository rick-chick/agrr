import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { PlanListPresenter } from './plan-list.presenter';
import { PlanListView, PlanListViewState } from '../../components/plans/plan-list.view';
import { PlanListDataDto } from '../../usecase/plans/load-plan-list.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { DeletePlanSuccessDto } from '../../usecase/plans/delete-plan.dtos';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';
import { PlanListEntry } from '../../domain/plans/plan-list-entry';

describe('PlanListPresenter', () => {
  let presenter: PlanListPresenter;
  let view: PlanListView;
  let lastControl: PlanListViewState | null;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [PlanListPresenter]
    });
    presenter = TestBed.inject(PlanListPresenter);

    lastControl = null;
    view = {
      get control(): PlanListViewState {
        return lastControl ?? { loading: true, error: null, entries: [], pendingUndoToast: null, pendingErrorFlash: null };
      },
      set control(value: PlanListViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('LoadPlanListOutputPort', () => {
    it('updates view.control on present(dto)', () => {
      const entries: PlanListEntry[] = [
        { plan: { id: 1, name: 'Plan A', status: 'pending', farm_id: 1 }, inputGap: null },
        {
          plan: { id: 2, name: 'Plan B', status: 'completed', farm_id: 2 },
          inputGap: { unrecordedCount: 1, actionRequiredCount: 0 }
        }
      ];
      const dto: PlanListDataDto = { entries };

      presenter.present(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBeNull();
      expect(lastControl!.entries).toEqual(entries);
    });

    it('queues pending error flash and updates view.control on onError(dto)', () => {
      const initialControl: PlanListViewState = { loading: true, error: null, entries: [], pendingUndoToast: null, pendingErrorFlash: null };
      lastControl = initialControl;

      const dto: ErrorDto = { message: 'Network error', scope: 'load-plan-list' };

      presenter.onError(dto);

      expect(lastControl!.pendingErrorFlash).toEqual({ type: 'error', text: 'Network error' });
      expect(lastControl).not.toBeNull();
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBe('Network error');
      expect(lastControl!.entries).toEqual([]);
    });

    it('does not set error in view.control when scope is not load-plan-list', () => {
      const initialEntries: PlanListEntry[] = [
        { plan: { id: 1, name: 'Plan A', status: 'pending', farm_id: 1 }, inputGap: null }
      ];
      const initialControl: PlanListViewState = {
        loading: false,
        error: null,
        entries: initialEntries,
        pendingUndoToast: null,
        pendingErrorFlash: null
      };
      lastControl = initialControl;

      const dto: ErrorDto = { message: 'Delete error', scope: 'delete-plan' };

      presenter.onError(dto);

      expect(lastControl!.pendingErrorFlash).toEqual({ type: 'error', text: 'Delete error' });
      expect(lastControl).not.toBeNull();
      expect(lastControl!.error).toBeNull();
      expect(lastControl!.entries).toEqual(initialEntries);
    });
  });

  describe('DeletePlanOutputPort', () => {
    it('updates view.control on onSuccess(dto) without undo', () => {
      const initialEntries: PlanListEntry[] = [
        { plan: { id: 1, name: 'Plan A', status: 'pending', farm_id: 1 }, inputGap: null },
        { plan: { id: 2, name: 'Plan B', status: 'completed', farm_id: 2 }, inputGap: null }
      ];
      lastControl = {
        loading: false,
        error: null,
        entries: initialEntries,
        pendingUndoToast: null,
        pendingErrorFlash: null
      };

      const dto: DeletePlanSuccessDto = { deletedPlanId: 1 };

      presenter.onSuccess(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.entries).toHaveLength(1);
      expect(lastControl!.entries[0].plan.id).toBe(2);
      expect(lastControl!.pendingUndoToast).toBeNull();
    });

    it('queues pending undo toast with refresh callback on onSuccess(dto)', () => {
      const initialEntries: PlanListEntry[] = [
        { plan: { id: 1, name: 'Plan A', status: 'pending', farm_id: 1 }, inputGap: null },
        { plan: { id: 2, name: 'Plan B', status: 'completed', farm_id: 2 }, inputGap: null }
      ];
      lastControl = {
        loading: false,
        error: null,
        entries: initialEntries,
        pendingUndoToast: null,
        pendingErrorFlash: null
      };

      const undoResponse: DeletionUndoResponse = {
        undo_token: 'token123',
        toast_message: 'プラン Plan A を削除しました',
        undo_path: '/undo_deletion?undo_token=token123',
        undo_deadline: '2026-02-03T12:00:00Z',
        resource: 'Plan A',
        resource_dom_id: 'cultivation_plan_1',
        redirect_path: '/plans',
        auto_hide_after: 60000
      };

      const refreshCallback = vi.fn();
      const dto: DeletePlanSuccessDto = {
        deletedPlanId: 1,
        undo: undoResponse,
        refresh: refreshCallback
      };

      presenter.onSuccess(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.entries).toHaveLength(1);
      expect(lastControl!.entries[0].plan.id).toBe(2);
      expect(lastControl!.pendingUndoToast).toEqual({
        message: undoResponse.toast_message,
        undoPath: undoResponse.undo_path,
        undoToken: undoResponse.undo_token,
        onRestored: refreshCallback,
        resourceLabel: undoResponse.resource
      });
    });

    it('does not queue undo toast when undo is missing', () => {
      const initialEntries: PlanListEntry[] = [
        { plan: { id: 1, name: 'Plan A', status: 'pending', farm_id: 1 }, inputGap: null }
      ];
      lastControl = {
        loading: false,
        error: null,
        entries: initialEntries,
        pendingUndoToast: null,
        pendingErrorFlash: null
      };

      const dto: DeletePlanSuccessDto = {
        deletedPlanId: 1,
        refresh: vi.fn()
      };

      presenter.onSuccess(dto);

      expect(lastControl!.entries).toHaveLength(0);
      expect(lastControl!.pendingUndoToast).toBeNull();
    });

    it('queues undo toast even when refresh callback is missing', () => {
      const initialEntries: PlanListEntry[] = [
        { plan: { id: 1, name: 'Plan A', status: 'pending', farm_id: 1 }, inputGap: null }
      ];
      lastControl = {
        loading: false,
        error: null,
        entries: initialEntries,
        pendingUndoToast: null,
        pendingErrorFlash: null
      };

      const undoResponse: DeletionUndoResponse = {
        undo_token: 'token123',
        toast_message: 'Deleted',
        undo_path: '/undo_deletion?undo_token=token123'
      };

      const dto: DeletePlanSuccessDto = {
        deletedPlanId: 1,
        undo: undoResponse
      };

      presenter.onSuccess(dto);

      expect(lastControl!.entries).toHaveLength(0);
      expect(lastControl!.pendingUndoToast?.message).toBe('Deleted');
      expect(lastControl!.pendingUndoToast?.onRestored).toBeUndefined();
    });
  });
});
