import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { FarmListPresenter } from './farm-list.presenter';
import { FarmListView, FarmListViewState } from '../../components/masters/farms/farm-list.view';
import { FarmListDataDto } from '../../usecase/farms/load-farm-list.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { DeleteFarmSuccessDto } from '../../usecase/farms/delete-farm.dtos';
import { UndoToastService } from '../../services/undo-toast.service';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

describe('FarmListPresenter', () => {
  let presenter: FarmListPresenter;
  let view: FarmListView;
  let lastControl: FarmListViewState | null;
  let mockUndoToastService: UndoToastService & { showWithUndo: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    mockUndoToastService = {
      showWithUndo: vi.fn()
    } as UndoToastService & { showWithUndo: ReturnType<typeof vi.fn> };

    TestBed.configureTestingModule({
      providers: [
        FarmListPresenter,
        { provide: UndoToastService, useValue: mockUndoToastService }
      ]
    });
    presenter = TestBed.inject(FarmListPresenter);

    lastControl = null;
    view = {
      get control(): FarmListViewState {
        return lastControl ?? { loading: true, error: null, farms: [] };
      },
      set control(value: FarmListViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('LoadFarmListOutputPort', () => {
    it('updates view.control on present(dto)', () => {
      const dto: FarmListDataDto = {
        farms: [
          { id: 1, name: 'Farm A', region: 'Region A', latitude: 35.0, longitude: 135.0, weather_data_status: 'pending' },
          { id: 2, name: 'Farm B', region: 'Region B', latitude: 36.0, longitude: 136.0, weather_data_status: 'completed' }
        ]
      };

      presenter.present(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBeNull();
      expect(lastControl!.farms).toEqual(dto.farms);
    });

    it('updates view.control on onError(dto)', () => {
      const initialControl: FarmListViewState = { loading: true, error: null, farms: [] };
      lastControl = initialControl;

      const dto: ErrorDto = { message: 'Network error' };

      presenter.onError(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBe('Network error');
      expect(lastControl!.farms).toEqual([]); // farms should be preserved
    });
  });

  describe('DeleteFarmOutputPort', () => {
    it('updates view.control on onSuccess(dto) without undo', () => {
      const initialFarms = [
        { id: 1, name: 'Farm A', region: 'Region A', latitude: 35.0, longitude: 135.0, weather_data_status: 'pending' as const },
        { id: 2, name: 'Farm B', region: 'Region B', latitude: 36.0, longitude: 136.0, weather_data_status: 'completed' as const }
      ];
      lastControl = { loading: false, error: null, farms: initialFarms };

      const dto: DeleteFarmSuccessDto = { deletedFarmId: 1 };

      presenter.onSuccess(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.farms).toHaveLength(1);
      expect(lastControl!.farms[0].id).toBe(2);
    });

    it('removes farm and shows undo toast on onSuccess(dto) with undo', () => {
      const initialFarms = [
        { id: 1, name: 'Farm A', region: 'Region A', latitude: 35.0, longitude: 135.0, weather_data_status: 'pending' as const },
        { id: 2, name: 'Farm B', region: 'Region B', latitude: 36.0, longitude: 136.0, weather_data_status: 'completed' as const }
      ];
      const initialControl: FarmListViewState = { loading: false, error: null, farms: initialFarms };
      lastControl = initialControl;

      const undoResponse: DeletionUndoResponse = {
        undo_token: 'token123',
        toast_message: 'Farm deleted',
        undo_path: '/api/v1/masters/farms/1/undo'
      };

      const dto: DeleteFarmSuccessDto = {
        deletedFarmId: 1,
        undo: undoResponse,
        refresh: vi.fn()
      };

      presenter.onSuccess(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.farms).toHaveLength(1);
      expect(lastControl!.farms[0].id).toBe(2);
      expect(mockUndoToastService.showWithUndo).toHaveBeenCalledWith(
        undoResponse.toast_message,
        undoResponse.undo_path,
        undoResponse.undo_token,
        expect.any(Function)
      );
    });
  });
});