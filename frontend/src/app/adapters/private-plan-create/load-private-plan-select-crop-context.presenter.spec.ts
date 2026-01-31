import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { LoadPrivatePlanSelectCropContextPresenter, LoadPrivatePlanSelectCropContextView } from './load-private-plan-select-crop-context.presenter';
import { PrivatePlanSelectCropContextDataDto } from '../../usecase/private-plan-create/load-private-plan-select-crop-context.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FlashMessageService } from '../../services/flash-message.service';

describe('LoadPrivatePlanSelectCropContextPresenter', () => {
  let presenter: LoadPrivatePlanSelectCropContextPresenter;
  let view: LoadPrivatePlanSelectCropContextView;
  let lastControl: any;
  let mockFlashMessageService: FlashMessageService & { show: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    mockFlashMessageService = { show: vi.fn() } as FlashMessageService & { show: ReturnType<typeof vi.fn> };

    TestBed.configureTestingModule({
      providers: [
        LoadPrivatePlanSelectCropContextPresenter,
        { provide: FlashMessageService, useValue: mockFlashMessageService }
      ]
    });
    presenter = TestBed.inject(LoadPrivatePlanSelectCropContextPresenter);

    lastControl = null;
    view = {
      get control() {
        return lastControl ?? { loading: true, error: null, farm: null, totalArea: 0, crops: [] };
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

  describe('LoadPrivatePlanSelectCropContextOutputPort', () => {
    it('updates view.control on present(dto)', () => {
      const dto: PrivatePlanSelectCropContextDataDto = {
        farm: { id: 1, name: 'Farm A', region: 'Region A', latitude: 35.0, longitude: 135.0, weather_data_status: 'pending' },
        totalArea: 100.5,
        crops: [
          { id: 1, name: 'Crop A', is_reference: false, groups: [] },
          { id: 2, name: 'Crop B', is_reference: false, groups: [] }
        ]
      };

      presenter.present(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl.loading).toBe(false);
      expect(lastControl.error).toBeNull();
      expect(lastControl.farm).toEqual(dto.farm);
      expect(lastControl.totalArea).toBe(dto.totalArea);
      expect(lastControl.crops).toEqual(dto.crops);
    });

    it('shows error via FlashMessageService and updates view.control on onError(dto)', () => {
      const initialControl = { loading: true, error: null, farm: null, totalArea: 0, crops: [] };
      lastControl = initialControl;

      const dto: ErrorDto = { message: 'Network error' };

      presenter.onError(dto);

      expect(mockFlashMessageService.show).toHaveBeenCalledTimes(1);
      expect(mockFlashMessageService.show).toHaveBeenCalledWith({ type: 'error', text: 'Network error' });
      expect(lastControl).not.toBeNull();
      expect(lastControl.loading).toBe(false);
      expect(lastControl.error).toBeNull();
      expect(lastControl.farm).toBeNull();
      expect(lastControl.totalArea).toBe(0);
      expect(lastControl.crops).toEqual([]);
    });

  });
});