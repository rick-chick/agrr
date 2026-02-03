import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { PlanListPresenter } from './plan-list.presenter';
import { PlanListView, PlanListViewState } from '../../components/plans/plan-list.view';
import { PlanListDataDto } from '../../usecase/plans/load-plan-list.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { DeletePlanSuccessDto } from '../../usecase/plans/delete-plan.dtos';
import { UndoToastService } from '../../services/undo-toast.service';
import { FlashMessageService } from '../../services/flash-message.service';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';
import { PlanSummary } from '../../domain/plans/plan-summary';

describe('PlanListPresenter', () => {
  let presenter: PlanListPresenter;
  let view: PlanListView;
  let lastControl: PlanListViewState | null;
  let mockUndoToastService: UndoToastService & { showWithUndo: ReturnType<typeof vi.fn> };
  let mockFlashMessageService: FlashMessageService & { show: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    mockUndoToastService = {
      showWithUndo: vi.fn()
    } as UndoToastService & { showWithUndo: ReturnType<typeof vi.fn> };
    mockFlashMessageService = { show: vi.fn() } as FlashMessageService & { show: ReturnType<typeof vi.fn> };

    TestBed.configureTestingModule({
      providers: [
        PlanListPresenter,
        { provide: UndoToastService, useValue: mockUndoToastService },
        { provide: FlashMessageService, useValue: mockFlashMessageService }
      ]
    });
    presenter = TestBed.inject(PlanListPresenter);

    lastControl = null;
    view = {
      get control(): PlanListViewState {
        return lastControl ?? { loading: true, error: null, plans: [] };
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
      const plans: PlanSummary[] = [
        { id: 1, name: 'Plan A', status: 'pending' },
        { id: 2, name: 'Plan B', status: 'completed' }
      ];
      const dto: PlanListDataDto = { plans };

      presenter.present(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBeNull();
      expect(lastControl!.plans).toEqual(plans);
    });

    it('shows error via FlashMessageService and updates view.control on onError(dto)', () => {
      const initialControl: PlanListViewState = { loading: true, error: null, plans: [] };
      lastControl = initialControl;

      const dto: ErrorDto = { message: 'Network error', scope: 'load-plan-list' };

      presenter.onError(dto);

      expect(mockFlashMessageService.show).toHaveBeenCalledTimes(1);
      expect(mockFlashMessageService.show).toHaveBeenCalledWith({ type: 'error', text: 'Network error' });
      expect(lastControl).not.toBeNull();
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBe('Network error');
      expect(lastControl!.plans).toEqual([]);
    });

    it('does not set error in view.control when scope is not load-plan-list', () => {
      const initialPlans: PlanSummary[] = [{ id: 1, name: 'Plan A', status: 'pending' }];
      const initialControl: PlanListViewState = { loading: false, error: null, plans: initialPlans };
      lastControl = initialControl;

      const dto: ErrorDto = { message: 'Delete error', scope: 'delete-plan' };

      presenter.onError(dto);

      expect(mockFlashMessageService.show).toHaveBeenCalledTimes(1);
      expect(mockFlashMessageService.show).toHaveBeenCalledWith({ type: 'error', text: 'Delete error' });
      expect(lastControl).not.toBeNull();
      expect(lastControl!.error).toBeNull();
      expect(lastControl!.plans).toEqual(initialPlans);
    });
  });

  describe('DeletePlanOutputPort', () => {
    it('updates view.control on onSuccess(dto) without undo', () => {
      const initialPlans: PlanSummary[] = [
        { id: 1, name: 'Plan A', status: 'pending' },
        { id: 2, name: 'Plan B', status: 'completed' }
      ];
      lastControl = { loading: false, error: null, plans: initialPlans };

      const dto: DeletePlanSuccessDto = { deletedPlanId: 1 };

      presenter.onSuccess(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.plans).toHaveLength(1);
      expect(lastControl!.plans[0].id).toBe(2);
      expect(mockUndoToastService.showWithUndo).not.toHaveBeenCalled();
    });

    it('removes plan and shows undo toast with refresh callback on onSuccess(dto)', () => {
      const initialPlans: PlanSummary[] = [
        { id: 1, name: 'Plan A', status: 'pending' },
        { id: 2, name: 'Plan B', status: 'completed' }
      ];
      const initialControl: PlanListViewState = { loading: false, error: null, plans: initialPlans };
      lastControl = initialControl;

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
      expect(lastControl!.plans).toHaveLength(1);
      expect(lastControl!.plans[0].id).toBe(2);
      expect(mockUndoToastService.showWithUndo).toHaveBeenCalledWith(
        undoResponse.toast_message,
        undoResponse.undo_path,
        undoResponse.undo_token,
        refreshCallback
      );
      const passedRefresh = mockUndoToastService.showWithUndo.mock.calls[0][3];
      expect(passedRefresh).toBe(refreshCallback);
    });

    it('does not show undo toast when undo is missing', () => {
      const initialPlans: PlanSummary[] = [
        { id: 1, name: 'Plan A', status: 'pending' }
      ];
      lastControl = { loading: false, error: null, plans: initialPlans };

      const dto: DeletePlanSuccessDto = {
        deletedPlanId: 1,
        refresh: vi.fn()
      };

      presenter.onSuccess(dto);

      expect(lastControl!.plans).toHaveLength(0);
      expect(mockUndoToastService.showWithUndo).not.toHaveBeenCalled();
    });

    it('shows undo toast even when refresh callback is missing', () => {
      const initialPlans: PlanSummary[] = [
        { id: 1, name: 'Plan A', status: 'pending' }
      ];
      lastControl = { loading: false, error: null, plans: initialPlans };

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

      expect(lastControl!.plans).toHaveLength(0);
      expect(mockUndoToastService.showWithUndo).toHaveBeenCalledWith(
        undoResponse.toast_message,
        undoResponse.undo_path,
        undoResponse.undo_token,
        undefined
      );
    });
  });
});
