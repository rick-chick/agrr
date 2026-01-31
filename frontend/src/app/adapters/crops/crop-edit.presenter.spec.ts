import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { CropEditPresenter } from './crop-edit.presenter';
import { CropEditView, CropEditViewState } from '../../components/masters/crops/crop-edit.view';
import { LoadCropForEditDataDto } from '../../usecase/crops/load-crop-for-edit.dtos';
import { UpdateCropSuccessDto } from '../../usecase/crops/update-crop.dtos';
import { CreateCropStageOutputDto } from '../../usecase/crops/create-crop-stage.dtos';
import { UpdateCropStageOutputDto } from '../../usecase/crops/update-crop-stage.dtos';
import { DeleteCropStageOutputDto } from '../../usecase/crops/delete-crop-stage.dtos';
import { UpdateTemperatureRequirementOutputDto } from '../../usecase/crops/update-temperature-requirement.dtos';
import { UpdateThermalRequirementOutputDto } from '../../usecase/crops/update-thermal-requirement.dtos';
import { UpdateSunshineRequirementOutputDto } from '../../usecase/crops/update-sunshine-requirement.dtos';
import { UpdateNutrientRequirementOutputDto } from '../../usecase/crops/update-nutrient-requirement.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FlashMessageService } from '../../services/flash-message.service';
import { CropStage } from '../../domain/crops/crop';

describe('CropEditPresenter', () => {
  let presenter: CropEditPresenter;
  let view: CropEditView;
  let lastControl: CropEditViewState | null;
  let mockFlashMessageService: FlashMessageService & { show: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    mockFlashMessageService = { show: vi.fn() } as FlashMessageService & { show: ReturnType<typeof vi.fn> };
    TestBed.configureTestingModule({
      providers: [
        CropEditPresenter,
        { provide: FlashMessageService, useValue: mockFlashMessageService }
      ]
    });
    presenter = TestBed.inject(CropEditPresenter);
    lastControl = null;
    view = {
      get control(): CropEditViewState {
        return lastControl ?? {
          loading: true,
          saving: false,
          error: null,
          formData: {
            name: '',
            variety: null,
            area_per_unit: null,
            revenue_per_area: null,
            region: null,
            groups: [],
            groupsDisplay: '',
            is_reference: false,
            crop_stages: []
          }
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
          crop_stages: [
            {
              id: 1,
              crop_id: 1,
              name: 'Stage 1',
              order: 1,
              temperature_requirement: {
                id: 1,
                crop_stage_id: 1,
                base_temperature: 10.0
              }
            }
          ]
        }
      };

      presenter.present(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBeNull();
      expect(lastControl!.formData.name).toBe('Test Crop');
      expect(lastControl!.formData.variety).toBe('Test Variety');
      expect(lastControl!.formData.area_per_unit).toBe(100.0);
      expect(lastControl!.formData.revenue_per_area).toBe(200.0);
      expect(lastControl!.formData.region).toBe('Test Region');
      expect(lastControl!.formData.groups).toEqual(['group1', 'group2']);
      expect(lastControl!.formData.groupsDisplay).toBe('group1, group2');
      expect(lastControl!.formData.is_reference).toBe(false);
      expect(lastControl!.formData.crop_stages).toEqual(dto.crop.crop_stages);
    });
  });

  describe('UpdateCropOutputPort', () => {
    it('does not update view.control on onSuccess(dto)', () => {
      const initialControl: CropEditViewState = {
        loading: false,
        saving: true,
        error: null,
        formData: {
          name: 'Test Crop',
          variety: 'Test Variety',
          area_per_unit: 100.0,
          revenue_per_area: 200.0,
          region: 'Test Region',
          groups: ['group1'],
          groupsDisplay: 'group1',
          is_reference: false,
          crop_stages: []
        }
      };
      lastControl = initialControl;

      const dto: UpdateCropSuccessDto = { success: true };

      presenter.onSuccess(dto);

      // onSuccess does not update view.control
      expect(lastControl).toEqual(initialControl);
    });

    it('shows error via FlashMessageService and updates view.control on onError(dto)', () => {
      const initialControl: CropEditViewState = {
        loading: false,
        saving: true,
        error: null,
        formData: {
          name: 'Test Crop',
          variety: 'Test Variety',
          area_per_unit: 100.0,
          revenue_per_area: 200.0,
          region: 'Test Region',
          groups: ['group1'],
          groupsDisplay: 'group1',
          is_reference: false,
          crop_stages: []
        }
      };
      lastControl = initialControl;

      const dto: ErrorDto = { message: 'Validation error' };

      presenter.onError(dto);

      expect(mockFlashMessageService.show).toHaveBeenCalledTimes(1);
      expect(mockFlashMessageService.show).toHaveBeenCalledWith({ type: 'error', text: 'Validation error' });
      expect(lastControl!.saving).toBe(false);
      expect(lastControl!.error).toBeNull();
    });
  });

  describe('CreateCropStageOutputPort', () => {
    it('adds new stage to formData.crop_stages on present(dto)', () => {
      const initialControl: CropEditViewState = {
        loading: false,
        saving: false,
        error: null,
        formData: {
          name: 'Test Crop',
          variety: null,
          area_per_unit: null,
          revenue_per_area: null,
          region: null,
          groups: [],
          groupsDisplay: '',
          is_reference: false,
          crop_stages: [
            {
              id: 1,
              crop_id: 1,
              name: 'Stage 1',
              order: 1
            }
          ]
        }
      };
      lastControl = initialControl;

      const newStage: CropStage = {
        id: 2,
        crop_id: 1,
        name: 'Stage 2',
        order: 2
      };
      const dto: CreateCropStageOutputDto = { stage: newStage };

      presenter.present(dto);

      expect(lastControl!.formData.crop_stages).toHaveLength(2);
      expect(lastControl!.formData.crop_stages[1]).toEqual(newStage);
    });
  });

  describe('UpdateCropStageOutputPort', () => {
    it('updates existing stage in formData.crop_stages on present(dto)', () => {
      const initialControl: CropEditViewState = {
        loading: false,
        saving: false,
        error: null,
        formData: {
          name: 'Test Crop',
          variety: null,
          area_per_unit: null,
          revenue_per_area: null,
          region: null,
          groups: [],
          groupsDisplay: '',
          is_reference: false,
          crop_stages: [
            {
              id: 1,
              crop_id: 1,
              name: 'Stage 1',
              order: 1
            }
          ]
        }
      };
      lastControl = initialControl;

      const updatedStage: CropStage = {
        id: 1,
        crop_id: 1,
        name: 'Updated Stage 1',
        order: 1
      };
      const dto: UpdateCropStageOutputDto = { stage: updatedStage };

      presenter.present(dto);

      expect(lastControl!.formData.crop_stages).toHaveLength(1);
      expect(lastControl!.formData.crop_stages[0]).toEqual(updatedStage);
    });
  });

  describe('DeleteCropStageOutputPort', () => {
    it('shows success message on present(dto)', () => {
      const dto: DeleteCropStageOutputDto = { success: true };

      presenter.present(dto);

      expect(mockFlashMessageService.show).toHaveBeenCalledTimes(1);
      expect(mockFlashMessageService.show).toHaveBeenCalledWith({ type: 'success', text: 'Stage deleted successfully' });
    });
  });

  describe('UpdateTemperatureRequirementOutputPort', () => {
    it('updates temperature_requirement of the corresponding stage on present(dto)', () => {
      const initialControl: CropEditViewState = {
        loading: false,
        saving: false,
        error: null,
        formData: {
          name: 'Test Crop',
          variety: null,
          area_per_unit: null,
          revenue_per_area: null,
          region: null,
          groups: [],
          groupsDisplay: '',
          is_reference: false,
          crop_stages: [
            {
              id: 1,
              crop_id: 1,
              name: 'Stage 1',
              order: 1,
              temperature_requirement: {
                id: 1,
                crop_stage_id: 1,
                base_temperature: 10.0
              }
            }
          ]
        }
      };
      lastControl = initialControl;

      const dto: UpdateTemperatureRequirementOutputDto = {
        requirement: {
          id: 1,
          crop_stage_id: 1,
          base_temperature: 15.0,
          optimal_min: 20.0
        }
      };

      presenter.present(dto);

      expect(lastControl!.formData.crop_stages[0].temperature_requirement).toEqual(dto.requirement);
    });
  });

  describe('UpdateThermalRequirementOutputPort', () => {
    it('updates thermal_requirement of the corresponding stage on present(dto)', () => {
      const initialControl: CropEditViewState = {
        loading: false,
        saving: false,
        error: null,
        formData: {
          name: 'Test Crop',
          variety: null,
          area_per_unit: null,
          revenue_per_area: null,
          region: null,
          groups: [],
          groupsDisplay: '',
          is_reference: false,
          crop_stages: [
            {
              id: 1,
              crop_id: 1,
              name: 'Stage 1',
              order: 1,
              thermal_requirement: {
                id: 1,
                crop_stage_id: 1,
                required_gdd: 100.0
              }
            }
          ]
        }
      };
      lastControl = initialControl;

      const dto: UpdateThermalRequirementOutputDto = {
        requirement: {
          id: 1,
          crop_stage_id: 1,
          required_gdd: 150.0
        }
      };

      presenter.present(dto);

      expect(lastControl!.formData.crop_stages[0].thermal_requirement).toEqual(dto.requirement);
    });
  });

  describe('UpdateSunshineRequirementOutputPort', () => {
    it('updates sunshine_requirement of the corresponding stage on present(dto)', () => {
      const initialControl: CropEditViewState = {
        loading: false,
        saving: false,
        error: null,
        formData: {
          name: 'Test Crop',
          variety: null,
          area_per_unit: null,
          revenue_per_area: null,
          region: null,
          groups: [],
          groupsDisplay: '',
          is_reference: false,
          crop_stages: [
            {
              id: 1,
              crop_id: 1,
              name: 'Stage 1',
              order: 1,
              sunshine_requirement: {
                id: 1,
                crop_stage_id: 1,
                minimum_sunshine_hours: 5.0
              }
            }
          ]
        }
      };
      lastControl = initialControl;

      const dto: UpdateSunshineRequirementOutputDto = {
        requirement: {
          id: 1,
          crop_stage_id: 1,
          minimum_sunshine_hours: 6.0,
          target_sunshine_hours: 8.0
        }
      };

      presenter.present(dto);

      expect(lastControl!.formData.crop_stages[0].sunshine_requirement).toEqual(dto.requirement);
    });
  });

  describe('UpdateNutrientRequirementOutputPort', () => {
    it('updates nutrient_requirement of the corresponding stage on present(dto)', () => {
      const initialControl: CropEditViewState = {
        loading: false,
        saving: false,
        error: null,
        formData: {
          name: 'Test Crop',
          variety: null,
          area_per_unit: null,
          revenue_per_area: null,
          region: null,
          groups: [],
          groupsDisplay: '',
          is_reference: false,
          crop_stages: [
            {
              id: 1,
              crop_id: 1,
              name: 'Stage 1',
              order: 1,
              nutrient_requirement: {
                id: 1,
                crop_stage_id: 1,
                daily_uptake_n: 1.0
              }
            }
          ]
        }
      };
      lastControl = initialControl;

      const dto: UpdateNutrientRequirementOutputDto = {
        requirement: {
          id: 1,
          crop_stage_id: 1,
          daily_uptake_n: 1.5,
          daily_uptake_p: 0.5,
          daily_uptake_k: 1.2,
          region: 'Test Region'
        }
      };

      presenter.present(dto);

      expect(lastControl!.formData.crop_stages[0].nutrient_requirement).toEqual(dto.requirement);
    });
  });
});