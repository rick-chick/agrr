import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { PesticideDetailPresenter } from './pesticide-detail.presenter';
import { PesticideDetailView, PesticideDetailViewState } from '../../components/masters/pesticides/pesticide-detail.view';
import { PesticideDetailDataDto } from '../../usecase/pesticides/load-pesticide-detail.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { DeletePesticideSuccessDto } from '../../usecase/pesticides/delete-pesticide.dtos';
import { ListRefreshBus } from '../../core/list-refresh/list-refresh-bus.service';
import { LIST_REFRESH_CHANNEL } from '../../core/list-refresh/list-refresh-keys';

describe('PesticideDetailPresenter', () => {
  let presenter: PesticideDetailPresenter;
  let lastControl: PesticideDetailViewState | null;
  let mockListRefreshBus: ListRefreshBus & { refresh: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    mockListRefreshBus = {
      refresh: vi.fn(),
      onRefresh: vi.fn(() => () => {})
    } as unknown as ListRefreshBus & { refresh: ReturnType<typeof vi.fn> };
    TestBed.configureTestingModule({
      providers: [
        PesticideDetailPresenter,
        { provide: ListRefreshBus, useValue: mockListRefreshBus }
      ]
    });
    presenter = TestBed.inject(PesticideDetailPresenter);
    lastControl = null;
    const view: PesticideDetailView = {
      get control(): PesticideDetailViewState {
        return lastControl ?? { loading: true, error: null, pesticide: null, pendingUndoToast: null, pendingErrorFlash: null };
      },
      set control(value: PesticideDetailViewState) {
        lastControl = value;
      },
      reload: vi.fn()
    };
    presenter.setView(view);
  });

  it('passes crop_name and pest_name through to view on present(dto)', () => {
    const dto: PesticideDetailDataDto = {
      pesticide: {
        id: 1,
        name: 'Spray A',
        crop_id: 51,
        pest_id: 54,
        is_reference: false,
        crop_name: 'Tomato',
        pest_name: 'Aphid'
      }
    };

    presenter.present(dto);

    expect(lastControl).not.toBeNull();
    expect(lastControl!.pesticide?.crop_name).toBe('Tomato');
    expect(lastControl!.pesticide?.pest_name).toBe('Aphid');
  });

  it('sets inline error key on onError(dto)', () => {
    lastControl = { loading: true, error: null, pesticide: null, pendingUndoToast: null, pendingErrorFlash: null };
    const dto: ErrorDto = { message: 'common.api_error.not_found' };

    presenter.onError(dto);

    expect(lastControl!.error).toBe('common.api_error.not_found');
    expect(lastControl!.pendingErrorFlash).toBeNull();
    expect(lastControl!.loading).toBe(false);
  });

  describe('DeletePesticideOutputPort', () => {
    it('queues pending undo toast with list refresh callback on onSuccess(dto)', () => {
      lastControl = {
        loading: false,
        error: null,
        pesticide: {
          id: 1,
          name: 'Spray A',
          crop_id: 51,
          pest_id: 54,
          is_reference: false
        },
        pendingUndoToast: null,
        pendingErrorFlash: null
      };

      const dto: DeletePesticideSuccessDto = {
        deletedPesticideId: 1,
        undo: {
          undo_token: 'token123',
          toast_message: 'Pesticide deleted',
          undo_path: '/undo_deletion?undo_token=token123',
          resource: 'Spray A'
        }
      };

      presenter.onSuccess(dto);

      expect(lastControl!.pendingUndoToast).toEqual({
        message: 'Pesticide deleted',
        undoPath: '/undo_deletion?undo_token=token123',
        undoToken: 'token123',
        onRestored: expect.any(Function),
        resourceLabel: 'Spray A'
      });
      lastControl!.pendingUndoToast!.onRestored!();
      expect(mockListRefreshBus.refresh).toHaveBeenCalledWith(LIST_REFRESH_CHANNEL.pesticides);
    });
  });
});
