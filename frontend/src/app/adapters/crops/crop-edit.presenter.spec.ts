import { TestBed } from '@angular/core/testing';
import { CropEditPresenter } from './crop-edit.presenter';
import { CropEditView, CropEditViewState } from '../../components/masters/crops/crop-edit.view';
import { LoadCropForEditDataDto } from '../../usecase/crops/load-crop-for-edit.dtos';
import { UpdateCropSuccessDto } from '../../usecase/crops/update-crop.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

describe('CropEditPresenter', () => {
  let presenter: CropEditPresenter;
  let view: CropEditView;
  let lastControl: CropEditViewState | null;

  const emptyFormData: CropEditViewState['formData'] = {
    name: '',
    variety: null,
    area_per_unit: null,
    revenue_per_area: null,
    region: null,
    groups: [],
    groupsDisplay: '',
    is_reference: false
  };

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [CropEditPresenter]
    });
    presenter = TestBed.inject(CropEditPresenter);
    lastControl = null;
    view = {
      get control(): CropEditViewState {
        return lastControl ?? {
          loading: true,
          saving: false,
          error: null,
          pendingErrorFlash: null,
          pendingSuccessFlash: null,
          formData: emptyFormData
        };
      },
      set control(value: CropEditViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  describe('LoadCropForEditOutputPort', () => {
    it('updates view.control with crop data on present(dto)', () => {
      const dto: LoadCropForEditDataDto = {
        crop: {
          id: 1,
          name: 'Test Crop',
          variety: 'Test Variety',
          area_per_unit: 100.0,
          revenue_per_area: 200.0,
          region: 'Test Region',
          groups: ['group1', 'group2'],
          is_reference: false,
          crop_stages: []
        }
      };

      presenter.present(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBeNull();
      expect(lastControl!.pendingSuccessFlash).toBeNull();
      expect(lastControl!.formData.name).toBe('Test Crop');
      expect(lastControl!.formData.variety).toBe('Test Variety');
      expect(lastControl!.formData.area_per_unit).toBe(100.0);
      expect(lastControl!.formData.revenue_per_area).toBe(200.0);
      expect(lastControl!.formData.region).toBe('Test Region');
      expect(lastControl!.formData.groups).toEqual(['group1', 'group2']);
      expect(lastControl!.formData.groupsDisplay).toBe('group1, group2');
      expect(lastControl!.formData.is_reference).toBe(false);
    });
  });

  describe('UpdateCropOutputPort', () => {
    it('queues pending success flash and sets saving false on onSuccess(dto)', () => {
      const initialControl: CropEditViewState = {
        loading: false,
        saving: true,
        error: null,
        pendingErrorFlash: null,
        pendingSuccessFlash: null,
        formData: {
          name: 'Test Crop',
          variety: 'Test Variety',
          area_per_unit: 100.0,
          revenue_per_area: 200.0,
          region: 'Test Region',
          groups: ['group1'],
          groupsDisplay: 'group1',
          is_reference: false
        }
      };
      lastControl = { ...initialControl, saving: true, pendingErrorFlash: null };

      const dto: UpdateCropSuccessDto = {
        crop: {
          id: 1,
          name: 'Test Crop',
          variety: null,
          area_per_unit: null,
          revenue_per_area: null,
          region: null,
          groups: [],
          is_reference: false,
          crop_stages: []
        }
      };

      presenter.onSuccess(dto);

      expect(lastControl!.saving).toBe(false);
      expect(lastControl!.pendingSuccessFlash).toEqual({ type: 'success', text: 'crops.flash.updated' });
    });

    it('queues pending error flash and updates view.control on onError(dto)', () => {
      const initialControl: CropEditViewState = {
        loading: false,
        saving: true,
        error: null,
        pendingErrorFlash: null,
        pendingSuccessFlash: null,
        formData: {
          name: 'Test Crop',
          variety: 'Test Variety',
          area_per_unit: 100.0,
          revenue_per_area: 200.0,
          region: 'Test Region',
          groups: ['group1'],
          groupsDisplay: 'group1',
          is_reference: false
        }
      };
      lastControl = initialControl;

      const dto: ErrorDto = { message: 'Validation error' };

      presenter.onError(dto);

      expect(lastControl!.pendingErrorFlash).toEqual({ type: 'error', text: 'Validation error' });
      expect(lastControl!.pendingSuccessFlash).toBeNull();
      expect(lastControl!.saving).toBe(false);
      expect(lastControl!.error).toBeNull();
    });
  });
});
