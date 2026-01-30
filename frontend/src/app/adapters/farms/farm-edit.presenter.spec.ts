import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { FarmEditPresenter } from './farm-edit.presenter';
import { FarmEditView, FarmEditViewState } from '../../components/masters/farms/farm-edit.view';
import { LoadFarmForEditDataDto } from '../../usecase/farms/load-farm-for-edit.dtos';
import { UpdateFarmSuccessDto } from '../../usecase/farms/update-farm.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FlashMessageService } from '../../services/flash-message.service';

describe('FarmEditPresenter', () => {
  let presenter: FarmEditPresenter;
  let view: FarmEditView;
  let lastControl: FarmEditViewState | null;
  let mockFlashMessageService: FlashMessageService & { show: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    mockFlashMessageService = { show: vi.fn() } as FlashMessageService & { show: ReturnType<typeof vi.fn> };
    TestBed.configureTestingModule({
      providers: [
        FarmEditPresenter,
        { provide: FlashMessageService, useValue: mockFlashMessageService }
      ]
    });
    presenter = TestBed.inject(FarmEditPresenter);
    lastControl = null;
    view = {
      get control(): FarmEditViewState {
        return lastControl ?? { loading: true, saving: false, error: null, formData: { name: '', region: '', latitude: 0, longitude: 0 } };
      },
      set control(value: FarmEditViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  describe('LoadFarmForEditOutputPort', () => {
    it('updates view.control on present(dto)', () => {
      const dto: LoadFarmForEditDataDto = {
        farm: {
          id: 1,
          name: 'Farm A',
          region: 'Region A',
          latitude: 35.0,
          longitude: 135.0,
          weather_data_status: 'completed'
        }
      };

      presenter.present(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBeNull();
      expect(lastControl!.saving).toBe(false);
      expect(lastControl!.formData).toEqual({
        name: 'Farm A',
        region: 'Region A',
        latitude: 35.0,
        longitude: 135.0
      });
    });

    it('shows error via FlashMessageService and updates view.control on onError(dto)', () => {
      const initialControl: FarmEditViewState = { loading: true, saving: false, error: null, formData: { name: '', region: '', latitude: 0, longitude: 0 } };
      lastControl = initialControl;

      const dto: ErrorDto = { message: 'Not found' };

      presenter.onError(dto);

      expect(mockFlashMessageService.show).toHaveBeenCalledTimes(1);
      expect(mockFlashMessageService.show).toHaveBeenCalledWith({ type: 'error', text: 'Not found' });
      expect(lastControl).not.toBeNull();
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.saving).toBe(false);
      expect(lastControl!.error).toBeNull();
    });
  });

  describe('UpdateFarmOutputPort', () => {
    it('does not update view.control on onSuccess(dto)', () => {
      const initialControl: FarmEditViewState = {
        loading: false,
        saving: true,
        error: null,
        formData: { name: 'Updated Farm', region: 'Updated Region', latitude: 36.0, longitude: 136.0 }
      };
      lastControl = initialControl;

      const dto: UpdateFarmSuccessDto = {
        farm: {
          id: 1,
          name: 'Updated Farm',
          region: 'Updated Region',
          latitude: 36.0,
          longitude: 136.0,
          weather_data_status: 'completed'
        }
      };

      presenter.onSuccess(dto);

      // onSuccess does not update view.control
      expect(lastControl).toEqual(initialControl);
    });
  });
});