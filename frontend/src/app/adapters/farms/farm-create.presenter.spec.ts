import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { FarmCreatePresenter } from './farm-create.presenter';
import { FarmCreateView, FarmCreateViewState } from '../../components/masters/farms/farm-create.view';
import { CreateFarmSuccessDto } from '../../usecase/farms/create-farm.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FlashMessageService } from '../../services/flash-message.service';

describe('FarmCreatePresenter', () => {
  let presenter: FarmCreatePresenter;
  let view: FarmCreateView;
  let lastControl: FarmCreateViewState | null;
  let mockFlashMessageService: FlashMessageService & { show: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    mockFlashMessageService = { show: vi.fn() } as FlashMessageService & { show: ReturnType<typeof vi.fn> };
    TestBed.configureTestingModule({
      providers: [
        FarmCreatePresenter,
        { provide: FlashMessageService, useValue: mockFlashMessageService }
      ]
    });
    presenter = TestBed.inject(FarmCreatePresenter);
    lastControl = null;
    view = {
      get control(): FarmCreateViewState {
        return lastControl ?? { saving: false, error: null, formData: { name: '', region: '', latitude: 0, longitude: 0 } };
      },
      set control(value: FarmCreateViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  describe('CreateFarmOutputPort', () => {
    it('does not update view.control on onSuccess(dto)', () => {
      const initialControl: FarmCreateViewState = { saving: true, error: null, formData: { name: 'New Farm', region: 'Region', latitude: 35.0, longitude: 135.0 } };
      lastControl = initialControl;

      const dto: CreateFarmSuccessDto = {
        farm: {
          id: 1,
          name: 'New Farm',
          region: 'Region',
          latitude: 35.0,
          longitude: 135.0,
          weather_data_status: 'pending'
        }
      };

      presenter.onSuccess(dto);

      // onSuccess does not update view.control
      expect(lastControl).toEqual(initialControl);
    });

    it('shows error via FlashMessageService and updates view.control on onError(dto)', () => {
      const initialControl: FarmCreateViewState = { saving: true, error: null, formData: { name: 'New Farm', region: 'Region', latitude: 35.0, longitude: 135.0 } };
      lastControl = initialControl;

      const dto: ErrorDto = { message: 'Validation error' };

      presenter.onError(dto);

      expect(mockFlashMessageService.show).toHaveBeenCalledTimes(1);
      expect(mockFlashMessageService.show).toHaveBeenCalledWith({ type: 'error', text: 'Validation error' });
      expect(lastControl).not.toBeNull();
      expect(lastControl!.saving).toBe(false);
      expect(lastControl!.error).toBeNull();
      expect(lastControl!.formData).toEqual(initialControl.formData); // formData preserved
    });
  });
});