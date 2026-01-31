import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { LoadPrivatePlanFarmsPresenter, LoadPrivatePlanFarmsView } from './load-private-plan-farms.presenter';
import { PrivatePlanFarmsDataDto } from '../../usecase/private-plan-create/load-private-plan-farms.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FlashMessageService } from '../../services/flash-message.service';

describe('LoadPrivatePlanFarmsPresenter', () => {
  let presenter: LoadPrivatePlanFarmsPresenter;
  let view: LoadPrivatePlanFarmsView;
  let lastControl: any;
  let mockFlashMessageService: FlashMessageService & { show: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    mockFlashMessageService = { show: vi.fn() } as FlashMessageService & { show: ReturnType<typeof vi.fn> };

    TestBed.configureTestingModule({
      providers: [
        LoadPrivatePlanFarmsPresenter,
        { provide: FlashMessageService, useValue: mockFlashMessageService }
      ]
    });
    presenter = TestBed.inject(LoadPrivatePlanFarmsPresenter);

    lastControl = null;
    view = {
      get control() {
        return lastControl ?? { loading: true, error: null, farms: [] };
      },
      set control(value: any) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('LoadPrivatePlanFarmsOutputPort', () => {
    it('updates view.control on present(dto)', () => {
      const dto: PrivatePlanFarmsDataDto = {
        farms: [
          { id: 1, name: 'Farm A', region: 'Region A', latitude: 35.0, longitude: 135.0, weather_data_status: 'pending' },
          { id: 2, name: 'Farm B', region: 'Region B', latitude: 36.0, longitude: 136.0, weather_data_status: 'completed' }
        ]
      };

      presenter.present(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl.loading).toBe(false);
      expect(lastControl.error).toBeNull();
      expect(lastControl.farms).toEqual(dto.farms);
    });

    it('shows error via FlashMessageService and updates view.control on onError(dto)', () => {
      const initialControl = { loading: true, error: null, farms: [] };
      lastControl = initialControl;

      const dto: ErrorDto = { message: 'Network error' };

      presenter.onError(dto);

      expect(mockFlashMessageService.show).toHaveBeenCalledTimes(1);
      expect(mockFlashMessageService.show).toHaveBeenCalledWith({ type: 'error', text: 'Network error' });
      expect(lastControl).not.toBeNull();
      expect(lastControl.loading).toBe(false);
      expect(lastControl.error).toBeNull();
      expect(lastControl.farms).toEqual([]); // farms should be preserved
    });

  });
});