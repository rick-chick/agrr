import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { PesticideDetailPresenter } from './pesticide-detail.presenter';
import { PesticideDetailView, PesticideDetailViewState } from '../../components/masters/pesticides/pesticide-detail.view';
import { PesticideDetailDataDto } from '../../usecase/pesticides/load-pesticide-detail.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { UndoToastService } from '../../services/undo-toast.service';
import { FlashMessageService } from '../../services/flash-message.service';
import { ListRefreshBus } from '../../core/list-refresh/list-refresh-bus.service';

describe('PesticideDetailPresenter', () => {
  let presenter: PesticideDetailPresenter;
  let lastControl: PesticideDetailViewState | null;
  let mockFlashMessageService: FlashMessageService & { show: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    mockFlashMessageService = { show: vi.fn() } as FlashMessageService & { show: ReturnType<typeof vi.fn> };
    TestBed.configureTestingModule({
      providers: [
        PesticideDetailPresenter,
        { provide: UndoToastService, useValue: { showWithUndo: vi.fn() } },
        { provide: FlashMessageService, useValue: mockFlashMessageService },
        { provide: ListRefreshBus, useValue: { refresh: vi.fn(), onRefresh: vi.fn(() => () => {}) } }
      ]
    });
    presenter = TestBed.inject(PesticideDetailPresenter);
    lastControl = null;
    const view: PesticideDetailView = {
      get control(): PesticideDetailViewState {
        return lastControl ?? { loading: true, error: null, pesticide: null };
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

  it('shows error via FlashMessageService on onError(dto)', () => {
    lastControl = { loading: true, error: null, pesticide: null };
    const dto: ErrorDto = { message: 'Not found' };

    presenter.onError(dto);

    expect(mockFlashMessageService.show).toHaveBeenCalledWith({ type: 'error', text: 'Not found' });
    expect(lastControl!.loading).toBe(false);
  });
});
