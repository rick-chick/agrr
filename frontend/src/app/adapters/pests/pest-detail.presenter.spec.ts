import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { PestDetailPresenter } from './pest-detail.presenter';
import { PestDetailView, PestDetailViewState } from '../../components/masters/pests/pest-detail.view';
import { ErrorDto } from '../../domain/shared/error.dto';
import { DeletePestSuccessDto } from '../../usecase/pests/delete-pest.dtos';
import { ListRefreshBus } from '../../core/list-refresh/list-refresh-bus.service';
import { LIST_REFRESH_CHANNEL } from '../../core/list-refresh/list-refresh-keys';

describe('PestDetailPresenter', () => {
  let presenter: PestDetailPresenter;
  let lastControl: PestDetailViewState | null;
  let mockListRefreshBus: ListRefreshBus & { refresh: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    mockListRefreshBus = {
      refresh: vi.fn(),
      onRefresh: vi.fn(() => () => {})
    } as unknown as ListRefreshBus & { refresh: ReturnType<typeof vi.fn> };
    TestBed.configureTestingModule({
      providers: [
        PestDetailPresenter,
        { provide: ListRefreshBus, useValue: mockListRefreshBus }
      ]
    });
    presenter = TestBed.inject(PestDetailPresenter);
    lastControl = null;
    const view: PestDetailView = {
      get control(): PestDetailViewState {
        return lastControl ?? { loading: true, error: null, pest: null, pendingUndoToast: null, pendingErrorFlash: null };
      },
      set control(value: PestDetailViewState) {
        lastControl = value;
      },
      reload: vi.fn()
    };
    presenter.setView(view);
  });

  it('sets inline error key on onError(dto) while loading', () => {
    lastControl = { loading: true, error: null, pest: null, pendingUndoToast: null, pendingErrorFlash: null };
    const dto: ErrorDto = { message: 'common.api_error.not_found' };

    presenter.onError(dto);

    expect(lastControl!.error).toBe('common.api_error.not_found');
    expect(lastControl!.pendingErrorFlash).toBeNull();
    expect(lastControl!.loading).toBe(false);
  });

  it('maps raw HTTP error text to i18n key on onError(dto) while loading', () => {
    lastControl = { loading: true, error: null, pest: null, pendingUndoToast: null, pendingErrorFlash: null };

    presenter.onError({
      message: 'Http failure response for https://agrr.local/api/v1/masters/pests/999: 404 Not Found'
    });

    expect(lastControl!.error).toBe('common.api_error.not_found');
    expect(lastControl!.error).not.toContain('Http failure');
  });

  it('queues pending error flash on onError(dto) when not loading', () => {
    lastControl = {
      loading: false,
      error: null,
      pest: { id: 1, name: 'Aphid', is_reference: false },
      pendingUndoToast: null,
      pendingErrorFlash: null
    };

    presenter.onError({ message: 'Not found' });

    expect(lastControl!.pendingErrorFlash).toEqual({ type: 'error', text: 'common.api_error.not_found' });
    expect(lastControl!.error).toBeNull();
  });

  describe('DeletePestOutputPort', () => {
    it('queues pending undo toast with list refresh callback on onSuccess(dto)', () => {
      lastControl = {
        loading: false,
        error: null,
        pest: { id: 1, name: 'Aphid', is_reference: false },
        pendingUndoToast: null,
        pendingErrorFlash: null
      };

      const dto: DeletePestSuccessDto = {
        deletedPestId: 1,
        undo: {
          undo_token: 'token123',
          toast_message: 'Pest deleted',
          undo_path: '/undo_deletion',
          resource: 'Aphid'
        }
      };

      presenter.onSuccess(dto);

      expect(lastControl!.pendingUndoToast).toEqual({
        message: 'Pest deleted',
        undoPath: '/undo_deletion',
        undoToken: 'token123',
        onRestored: expect.any(Function),
        resourceLabel: 'Aphid'
      });
      lastControl!.pendingUndoToast!.onRestored!();
      expect(mockListRefreshBus.refresh).toHaveBeenCalledWith(LIST_REFRESH_CHANNEL.pests);
    });
  });
});
