import { TestBed } from '@angular/core/testing';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PublicPlanSelectCropPresenter } from './public-plan-select-crop.presenter';
import { PublicPlanSelectCropView, PublicPlanSelectCropViewState } from '../../components/public-plans/public-plan-select-crop.view';
import { Crop } from '../../domain/crops/crop';
import { CreatePublicPlanResponse } from '../../usecase/public-plans/public-plan-gateway';
import { ErrorDto } from '../../domain/shared/error.dto';

describe('PublicPlanSelectCropPresenter', () => {
  let presenter: PublicPlanSelectCropPresenter;
  let view: PublicPlanSelectCropView;
  let lastControl: PublicPlanSelectCropViewState | null;
  let consoleLogSpy: ReturnType<typeof vi.spyOn>;
  let consoleErrorSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    consoleLogSpy = vi.spyOn(console, 'log').mockImplementation(() => {});
    consoleErrorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

    TestBed.configureTestingModule({
      providers: [PublicPlanSelectCropPresenter]
    });

    presenter = TestBed.inject(PublicPlanSelectCropPresenter);
    lastControl = null;
    view = {
      get control(): PublicPlanSelectCropViewState {
        return lastControl ?? { loading: true, error: null, crops: [], saving: false };
      },
      set control(value: PublicPlanSelectCropViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('LoadPublicPlanCropsOutputPort', () => {
    it('should present crops data to view', () => {
      const crops: Crop[] = [
        { id: 1, name: 'Crop 1', is_reference: false, groups: [] },
        { id: 2, name: 'Crop 2', is_reference: false, groups: [] }
      ];
      const dto = { crops };

      presenter.present(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBeNull();
      expect(lastControl!.crops).toEqual(crops);
    });

    it('should throw error when view is not set', () => {
      const presenterWithoutView = new PublicPlanSelectCropPresenter();
      const crops: Crop[] = [{ id: 1, name: 'Crop 1', is_reference: false, groups: [] }];
      const dto = { crops };

      expect(() => presenterWithoutView.present(dto)).toThrow('Presenter: view not set');
    });
  });

  describe('CreatePublicPlanOutputPort', () => {
    describe('onSuccess', () => {
      it('should log plan_id and update view state', () => {
        const initialControl: PublicPlanSelectCropViewState = {
          loading: false,
          error: null,
          crops: [{ id: 1, name: 'Crop 1', is_reference: false, groups: [] }],
          saving: true
        };
        lastControl = initialControl;
        const dto: CreatePublicPlanResponse = { plan_id: 123 };

        presenter.onSuccess(dto);

        expect(consoleLogSpy).toHaveBeenCalledWith(
          '✅ [PublicPlanSelectCropPresenter] Plan created successfully. plan_id:',
          123
        );
        expect(lastControl).not.toBeNull();
        expect(lastControl!.saving).toBe(false);
        expect(lastControl!.error).toBeNull();
        expect(lastControl!.crops).toEqual(initialControl.crops);
      });

      it('should clear error when plan creation succeeds', () => {
        const initialControl: PublicPlanSelectCropViewState = {
          loading: false,
          error: 'Previous error',
          crops: [],
          saving: true
        };
        lastControl = initialControl;
        const dto: CreatePublicPlanResponse = { plan_id: 456 };

        presenter.onSuccess(dto);

        expect(lastControl!.error).toBeNull();
        expect(lastControl!.saving).toBe(false);
      });

      it('should throw error when view is not set', () => {
        const presenterWithoutView = new PublicPlanSelectCropPresenter();
        const dto: CreatePublicPlanResponse = { plan_id: 789 };

        expect(() => presenterWithoutView.onSuccess(dto)).toThrow('Presenter: view not set');
      });
    });

    describe('onError', () => {
      it('should log error and update view state with error message', () => {
        const initialControl: PublicPlanSelectCropViewState = {
          loading: false,
          error: null,
          crops: [{ id: 1, name: 'Crop 1', is_reference: false, groups: [] }],
          saving: true
        };
        lastControl = initialControl;
        const dto: ErrorDto = { message: 'Failed to create plan' };

        presenter.onError(dto);

        expect(consoleErrorSpy).toHaveBeenCalledWith(
          '❌ [PublicPlanSelectCropPresenter] Plan creation failed:',
          'Failed to create plan'
        );
        expect(lastControl).not.toBeNull();
        expect(lastControl!.loading).toBe(false);
        expect(lastControl!.saving).toBe(false);
        expect(lastControl!.error).toBe('Failed to create plan');
        expect(lastControl!.crops).toEqual(initialControl.crops);
      });

      it('should clear crops when loading was true', () => {
        const initialControl: PublicPlanSelectCropViewState = {
          loading: true,
          error: null,
          crops: [{ id: 1, name: 'Crop 1', is_reference: false, groups: [] }],
          saving: false
        };
        lastControl = initialControl;
        const dto: ErrorDto = { message: 'Network error' };

        presenter.onError(dto);

        expect(lastControl!.crops).toEqual([]);
        expect(lastControl!.error).toBe('Network error');
      });

      it('should preserve crops when loading was false', () => {
        const crops: Crop[] = [
          { id: 1, name: 'Crop 1', is_reference: false, groups: [] },
          { id: 2, name: 'Crop 2', is_reference: false, groups: [] }
        ];
        const initialControl: PublicPlanSelectCropViewState = {
          loading: false,
          error: null,
          crops,
          saving: true
        };
        lastControl = initialControl;
        const dto: ErrorDto = { message: 'Validation error' };

        presenter.onError(dto);

        expect(lastControl!.crops).toEqual(crops);
        expect(lastControl!.error).toBe('Validation error');
      });

      it('should throw error when view is not set', () => {
        const presenterWithoutView = new PublicPlanSelectCropPresenter();
        const dto: ErrorDto = { message: 'Error' };

        expect(() => presenterWithoutView.onError(dto)).toThrow('Presenter: view not set');
      });
    });
  });
});
