import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { AgriculturalTaskDetailPresenter } from './agricultural-task-detail.presenter';
import {
  AgriculturalTaskDetailView,
  AgriculturalTaskDetailViewState
} from '../../components/masters/agricultural-tasks/agricultural-task-detail.view';
import { ErrorDto } from '../../domain/shared/error.dto';
import { DeleteAgriculturalTaskSuccessDto } from '../../usecase/agricultural-tasks/delete-agricultural-task.dtos';
import { ListRefreshBus } from '../../core/list-refresh/list-refresh-bus.service';
import { LIST_REFRESH_CHANNEL } from '../../core/list-refresh/list-refresh-keys';

describe('AgriculturalTaskDetailPresenter', () => {
  let presenter: AgriculturalTaskDetailPresenter;
  let view: AgriculturalTaskDetailView;
  let lastControl: AgriculturalTaskDetailViewState | null;
  let mockListRefreshBus: ListRefreshBus & { refresh: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    mockListRefreshBus = {
      refresh: vi.fn(),
      onRefresh: vi.fn(() => () => {})
    } as unknown as ListRefreshBus & { refresh: ReturnType<typeof vi.fn> };
    TestBed.configureTestingModule({
      providers: [
        AgriculturalTaskDetailPresenter,
        { provide: ListRefreshBus, useValue: mockListRefreshBus }
      ]
    });
    presenter = TestBed.inject(AgriculturalTaskDetailPresenter);
    lastControl = null;
    view = {
      get control(): AgriculturalTaskDetailViewState {
        return lastControl ?? { loading: true, error: null, agriculturalTask: null, pendingUndoToast: null, pendingErrorFlash: null };
      },
      set control(value: AgriculturalTaskDetailViewState) {
        lastControl = value;
      },
      reload: vi.fn()
    };
    presenter.setView(view);
  });

  describe('LoadAgriculturalTaskDetailOutputPort', () => {
    it('sets i18n error key on view.control when loading fails', () => {
      const initialControl: AgriculturalTaskDetailViewState = {
        loading: true,
        error: null,
        agriculturalTask: null,
        pendingUndoToast: null,
        pendingErrorFlash: null
      };
      lastControl = initialControl;

      const dto: ErrorDto = { message: 'Not found' };

      presenter.onError(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBe('common.api_error.not_found');
      expect(lastControl!.pendingErrorFlash).toBeNull();
    });

    it('queues pending error flash when error occurs after load', () => {
      lastControl = {
        loading: false,
        error: null,
        agriculturalTask: {
          id: 1,
          name: 'Task A',
          required_tools: [],
          is_reference: false
        },
        pendingUndoToast: null,
        pendingErrorFlash: null
      };

      presenter.onError({ message: 'Not found' });

      expect(lastControl!.error).toBeNull();
      expect(lastControl!.pendingErrorFlash).toEqual({
        type: 'error',
        text: 'common.api_error.not_found'
      });
    });
  });

  describe('DeleteAgriculturalTaskOutputPort', () => {
    it('queues pending undo toast with list refresh callback on onSuccess(dto)', () => {
      lastControl = {
        loading: false,
        error: null,
        agriculturalTask: {
          id: 1,
          name: 'Task A',
          required_tools: [],
          is_reference: false
        },
        pendingUndoToast: null,
        pendingErrorFlash: null
      };

      const dto: DeleteAgriculturalTaskSuccessDto = {
        deletedAgriculturalTaskId: 1,
        undo: {
          undo_token: 'token123',
          toast_message: 'Task deleted',
          undo_path: '/undo_deletion?undo_token=token123',
          resource: 'Task A'
        }
      };

      presenter.onSuccess(dto);

      expect(lastControl!.pendingUndoToast).toEqual({
        message: 'Task deleted',
        undoPath: '/undo_deletion?undo_token=token123',
        undoToken: 'token123',
        onRestored: expect.any(Function),
        resourceLabel: 'Task A'
      });
      lastControl!.pendingUndoToast!.onRestored!();
      expect(mockListRefreshBus.refresh).toHaveBeenCalledWith(LIST_REFRESH_CHANNEL.agriculturalTasks);
    });
  });
});
