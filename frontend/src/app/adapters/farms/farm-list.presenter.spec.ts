import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { FarmListPresenter } from './farm-list.presenter';
import { FarmListView, FarmListViewState } from '../../components/masters/farms/farm-list.view';
import { FarmListDataDto } from '../../usecase/farms/load-farm-list.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { DeleteFarmSuccessDto } from '../../usecase/farms/delete-farm.dtos';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

describe('FarmListPresenter', () => {
  let presenter: FarmListPresenter;
  let view: FarmListView;
  let lastControl: FarmListViewState | null;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [FarmListPresenter]
    });
    presenter = TestBed.inject(FarmListPresenter);

    lastControl = null;
    view = {
      get control(): FarmListViewState {
        return lastControl ?? { loading: true, error: null, farms: [], pendingUndoToast: null, pendingErrorFlash: null };
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
      expect(lastControl!.pendingUndoToast).toBeNull();
      expect(lastControl!.pendingErrorFlash).toBeNull();
    });

    it('handles farms with is_reference field for admin users', () => {
      const dto: FarmListDataDto = {
        farms: [
          { id: 1, name: 'User Farm', region: 'jp', latitude: 35.6895, longitude: 139.6917, weather_data_status: 'completed', is_reference: false },
          { id: 2, name: 'Reference Farm', region: 'jp', latitude: 43.0642, longitude: 141.3468, weather_data_status: 'pending', is_reference: true }
        ]
      };

      presenter.present(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBeNull();
      expect(lastControl!.farms).toHaveLength(2);
      expect(lastControl!.farms[0].is_reference).toBe(false);
      expect(lastControl!.farms[1].is_reference).toBe(true);
    });

    it('queues pending error flash and updates view.control on onError(dto)', () => {
      const initialControl: FarmListViewState = {
        loading: true,
        error: null,
        farms: [],
        pendingUndoToast: null,
        pendingErrorFlash: null
      };
      lastControl = initialControl;

      const dto: ErrorDto = { message: 'Network error' };

      presenter.onError(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBeNull();
      expect(lastControl!.farms).toEqual([]);
      expect(lastControl!.pendingErrorFlash).toEqual({ type: 'error', text: 'Network error' });
    });
  });

  describe('DeleteFarmOutputPort', () => {
    it('updates view.control on onSuccess(dto) without undo', () => {
      const initialFarms = [
        { id: 1, name: 'Farm A', region: 'Region A', latitude: 35.0, longitude: 135.0, weather_data_status: 'pending' as const },
        { id: 2, name: 'Farm B', region: 'Region B', latitude: 36.0, longitude: 136.0, weather_data_status: 'completed' as const }
      ];
      lastControl = { loading: false, error: null, farms: initialFarms, pendingUndoToast: null, pendingErrorFlash: null };

      const dto: DeleteFarmSuccessDto = { deletedFarmId: 1 };

      presenter.onSuccess(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.farms).toHaveLength(1);
      expect(lastControl!.farms[0].id).toBe(2);
      expect(lastControl!.pendingUndoToast).toBeNull();
      expect(lastControl!.pendingErrorFlash).toBeNull();
    });

    it('queues pending undo toast with refresh callback on onSuccess(dto)', () => {
      const initialFarms = [
        { id: 1, name: 'Farm A', region: 'Region A', latitude: 35.0, longitude: 135.0, weather_data_status: 'pending' as const },
        { id: 2, name: 'Farm B', region: 'Region B', latitude: 36.0, longitude: 136.0, weather_data_status: 'completed' as const }
      ];
      lastControl = { loading: false, error: null, farms: initialFarms, pendingUndoToast: null, pendingErrorFlash: null };

      const undoResponse: DeletionUndoResponse = {
        undo_token: 'token123',
        toast_message: 'Farm deleted',
        undo_path: '/undo_deletion?undo_token=token123'
      };

      const refreshCallback = vi.fn();
      const dto: DeleteFarmSuccessDto = {
        deletedFarmId: 1,
        undo: undoResponse,
        refresh: refreshCallback
      };

      presenter.onSuccess(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.farms).toHaveLength(1);
      expect(lastControl!.farms[0].id).toBe(2);
      expect(lastControl!.pendingUndoToast).toEqual({
        message: undoResponse.toast_message,
        undoPath: undoResponse.undo_path,
        undoToken: undoResponse.undo_token,
        onRestored: refreshCallback,
        resourceLabel: undoResponse.resource
      });
    });
  });
});
