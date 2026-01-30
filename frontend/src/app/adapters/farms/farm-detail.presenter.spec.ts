import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { FarmDetailPresenter } from './farm-detail.presenter';
import { FarmDetailView, FarmDetailViewState } from '../../components/masters/farms/farm-detail.view';
import { FarmDetailDataDto } from '../../usecase/farms/load-farm-detail.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { DeleteFarmSuccessDto } from '../../usecase/farms/delete-farm.dtos';
import { FarmWeatherUpdateDto } from '../../usecase/farms/subscribe-farm-weather.dtos';
import { UndoToastService } from '../../services/undo-toast.service';

describe('FarmDetailPresenter', () => {
  let presenter: FarmDetailPresenter;
  let view: FarmDetailView;
  let lastControl: FarmDetailViewState | null;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        FarmDetailPresenter,
        { provide: UndoToastService, useValue: { showWithUndo: vi.fn() } }
      ]
    });
    presenter = TestBed.inject(FarmDetailPresenter);
    lastControl = null;
    view = {
      get control(): FarmDetailViewState {
        return lastControl ?? { loading: true, error: null, farm: null, fields: [] };
      },
      set control(value: FarmDetailViewState) {
        lastControl = value;
      },
      load: vi.fn(),
      reload: vi.fn()
    };
    presenter.setView(view);
  });

  describe('LoadFarmDetailOutputPort', () => {
    it('updates view.control on present(dto)', () => {
      const dto: FarmDetailDataDto = {
        farm: {
          id: 1,
          name: 'Farm A',
          region: 'Region A',
          latitude: 35.0,
          longitude: 135.0,
          weather_data_status: 'completed'
        },
        fields: [
          { id: 1, farm_id: 1, user_id: null, name: 'Field 1', description: null, area: 100, daily_fixed_cost: 50, region: 'Region 1', created_at: '2023-01-01', updated_at: '2023-01-01' },
          { id: 2, farm_id: 1, user_id: null, name: 'Field 2', description: null, area: 200, daily_fixed_cost: 100, region: 'Region 1', created_at: '2023-01-01', updated_at: '2023-01-01' }
        ]
      };

      presenter.present(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBeNull();
      expect(lastControl!.farm).toEqual(dto.farm);
      expect(lastControl!.fields).toEqual(dto.fields);
    });

    it('updates view.control on onError(dto)', () => {
      const initialControl: FarmDetailViewState = { loading: true, error: null, farm: null, fields: [] };
      lastControl = initialControl;

      const dto: ErrorDto = { message: 'Not found' };

      presenter.onError(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBe('Not found');
    });
  });

  describe('SubscribeFarmWeatherOutputPort', () => {
    it('updates weather data on presentWeather(dto)', () => {
      const initialFarm = {
        id: 1,
        name: 'Farm A',
        region: 'Region A',
        latitude: 35.0,
        longitude: 135.0,
        weather_data_status: 'pending' as const
      };
      lastControl = { loading: false, error: null, farm: initialFarm, fields: [] };

      const dto: FarmWeatherUpdateDto = {
        id: 1,
        weather_data_status: 'completed',
        weather_data_progress: 100,
        weather_data_fetched_years: 5,
        weather_data_total_years: 5
      };

      presenter.presentWeather(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.farm!.weather_data_status).toBe('completed');
      expect(lastControl!.farm!.weather_data_progress).toBe(100);
      expect(lastControl!.farm!.weather_data_fetched_years).toBe(5);
      expect(lastControl!.farm!.weather_data_total_years).toBe(5);
    });

    it('ignores weather update for different farm id', () => {
      const initialFarm = {
        id: 1,
        name: 'Farm A',
        region: 'Region A',
        latitude: 35.0,
        longitude: 135.0,
        weather_data_status: 'pending' as const
      };
      lastControl = { loading: false, error: null, farm: initialFarm, fields: [] };

      const dto: FarmWeatherUpdateDto = {
        id: 2, // different id
        weather_data_status: 'completed'
      };

      presenter.presentWeather(dto);

      expect(lastControl!.farm!.weather_data_status).toBe('pending'); // unchanged
    });
  });

  describe('DeleteFarmOutputPort', () => {
    it('handles onSuccess(dto) with undo', () => {
      const dto: DeleteFarmSuccessDto = {
        deletedFarmId: 1,
        undo: {
          undo_token: 'token123',
          toast_message: 'Farm deleted',
          undo_path: '/api/v1/masters/farms/1/undo'
        }
      };

      // onSuccess does not update view.control directly
      presenter.onSuccess(dto);

      // The actual undo handling is done by UndoToastService; on restore, view.reload() is called
    });
  });
});