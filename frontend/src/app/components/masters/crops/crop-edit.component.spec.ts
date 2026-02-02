import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { of } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';

import { CropEditComponent } from './crop-edit.component';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';
import { CropStage } from '../../../domain/crops/crop';
import { AuthService } from '../../../services/auth.service';

// Import initialFormData from the component
const initialFormData = {
  name: '',
  variety: null,
  area_per_unit: null,
  revenue_per_area: null,
  region: null,
  groups: [],
  groupsDisplay: '',
  is_reference: false,
  crop_stages: []
};
import { CropEditPresenter } from '../../../adapters/crops/crop-edit.presenter';
import { LoadCropForEditUseCase } from '../../../usecase/crops/load-crop-for-edit.usecase';
import { UpdateCropUseCase } from '../../../usecase/crops/update-crop.usecase';
import { CreateCropStageUseCase } from '../../../usecase/crops/create-crop-stage.usecase';
import { UpdateCropStageUseCase } from '../../../usecase/crops/update-crop-stage.usecase';
import { DeleteCropStageUseCase } from '../../../usecase/crops/delete-crop-stage.usecase';
import { UpdateTemperatureRequirementUseCase } from '../../../usecase/crops/update-temperature-requirement.usecase';
import { UpdateThermalRequirementUseCase } from '../../../usecase/crops/update-thermal-requirement.usecase';
import { UpdateSunshineRequirementUseCase } from '../../../usecase/crops/update-sunshine-requirement.usecase';
import { UpdateNutrientRequirementUseCase } from '../../../usecase/crops/update-nutrient-requirement.usecase';

describe('CropEditComponent', () => {
  let component: CropEditComponent;
  let fixture: ComponentFixture<CropEditComponent>;
  let mockActivatedRoute: any;
  let mockLoadUseCase: any;
  let mockUpdateUseCase: any;
  let mockCreateCropStageUseCase: any;
  let mockUpdateCropStageUseCase: any;
  let mockDeleteCropStageUseCase: any;
  let mockUpdateTemperatureRequirementUseCase: any;
  let mockUpdateThermalRequirementUseCase: any;
  let mockUpdateSunshineRequirementUseCase: any;
  let mockUpdateNutrientRequirementUseCase: any;
  let translateService: TranslateService;
  let mockAuthService: any;

  beforeEach(async () => {
    mockActivatedRoute = {
      snapshot: {
        paramMap: {
          get: () => '1'
        }
      }
    };

    mockLoadUseCase = { execute: vi.fn() };
    mockUpdateUseCase = { execute: vi.fn() };
    mockCreateCropStageUseCase = { execute: vi.fn() };
    mockUpdateCropStageUseCase = { execute: vi.fn() };
    mockDeleteCropStageUseCase = { execute: vi.fn() };
    mockUpdateTemperatureRequirementUseCase = { execute: vi.fn() };
    mockUpdateThermalRequirementUseCase = { execute: vi.fn() };
    mockUpdateSunshineRequirementUseCase = { execute: vi.fn() };
    mockUpdateNutrientRequirementUseCase = { execute: vi.fn() };
    mockAuthService = {
      user: vi.fn(() => ({ admin: true, region: 'us' }))
    };
    // Use real TranslateService via TranslateModule.forRoot() and set translations in the test

    await TestBed.configureTestingModule({
      imports: [
        CropEditComponent,
        RegionSelectComponent,
        TranslateModule.forRoot({
          fallbackLang: 'en'
        })
      ],
      providers: [
        CropEditPresenter,
        { provide: ActivatedRoute, useValue: mockActivatedRoute },
        { provide: LoadCropForEditUseCase, useValue: mockLoadUseCase },
        { provide: UpdateCropUseCase, useValue: mockUpdateUseCase },
        { provide: CreateCropStageUseCase, useValue: mockCreateCropStageUseCase },
        { provide: UpdateCropStageUseCase, useValue: mockUpdateCropStageUseCase },
        { provide: DeleteCropStageUseCase, useValue: mockDeleteCropStageUseCase },
        { provide: UpdateTemperatureRequirementUseCase, useValue: mockUpdateTemperatureRequirementUseCase },
        { provide: UpdateThermalRequirementUseCase, useValue: mockUpdateThermalRequirementUseCase },
        { provide: UpdateSunshineRequirementUseCase, useValue: mockUpdateSunshineRequirementUseCase },
        { provide: UpdateNutrientRequirementUseCase, useValue: mockUpdateNutrientRequirementUseCase },
        TranslateModule,
        { provide: AuthService, useValue: mockAuthService }
      ]
    }).compileComponents();

    // Ensure component's internal provider for LoadCropForEditUseCase is replaced with our mock
    TestBed.overrideProvider(LoadCropForEditUseCase, { useValue: mockLoadUseCase });
    // Ensure component's internal provider for UpdateCropUseCase is replaced with our mock
    TestBed.overrideProvider(UpdateCropUseCase, { useValue: mockUpdateUseCase });
    // Ensure component's internal providers for stage and requirement usecases are replaced with our mocks
    TestBed.overrideProvider(CreateCropStageUseCase, { useValue: mockCreateCropStageUseCase });
    TestBed.overrideProvider(UpdateCropStageUseCase, { useValue: mockUpdateCropStageUseCase });
    TestBed.overrideProvider(DeleteCropStageUseCase, { useValue: mockDeleteCropStageUseCase });
    TestBed.overrideProvider(UpdateTemperatureRequirementUseCase, { useValue: mockUpdateTemperatureRequirementUseCase });
    TestBed.overrideProvider(UpdateThermalRequirementUseCase, { useValue: mockUpdateThermalRequirementUseCase });
    TestBed.overrideProvider(UpdateSunshineRequirementUseCase, { useValue: mockUpdateSunshineRequirementUseCase });
    TestBed.overrideProvider(UpdateNutrientRequirementUseCase, { useValue: mockUpdateNutrientRequirementUseCase });
    // Create fixture after overrides
    fixture = TestBed.createComponent(CropEditComponent);
    component = fixture.componentInstance;

    // Configure TranslateService translations for tests
    translateService = TestBed.inject(TranslateService);
    translateService.setTranslation('ja', {
      crops: {
        edit: {
          stage_title: 'ステージ {{order}}'
        },
        form: {
          region_label: 'Region',
          region_blank: '',
          region_jp: 'Japan',
          region_us: 'United States',
          region_in: 'India'
        }
      }
    }, true);
    translateService.use('ja');
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should load crop on init', () => {
    // Ensure cropId is set correctly
    expect(component['cropId']).toBe(1);
    fixture.detectChanges(); // This triggers ngOnInit
    expect(mockLoadUseCase.execute).toHaveBeenCalledWith({ cropId: 1 });
  });

  it('should call createCropStageUseCase when addCropStage is called', () => {
    component.addCropStage();
    expect(mockCreateCropStageUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      payload: {
        name: 'Stage 1',
        order: 1
      }
    });
  });

  it('should call updateCropStageUseCase when updateCropStage is called', () => {
    component.updateCropStage(1, { name: 'New Name' });
    expect(mockUpdateCropStageUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1,
      payload: { name: 'New Name' }
    });
  });

  it('should call deleteCropStageUseCase when deleteCropStage is called with confirmation', () => {
    vi.spyOn(window, 'confirm').mockReturnValue(true);
    component.deleteCropStage(1);
    expect(mockDeleteCropStageUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1
    });
  });

  it('should not call deleteCropStageUseCase when deleteCropStage is cancelled', () => {
    vi.spyOn(window, 'confirm').mockReturnValue(false);
    component.deleteCropStage(1);
    expect(mockDeleteCropStageUseCase.execute).not.toHaveBeenCalled();
  });

  it('should call updateTemperatureRequirementUseCase when updateTemperatureRequirement is called', () => {
    component.updateTemperatureRequirement(1, { base_temperature: 10 });
    expect(mockUpdateTemperatureRequirementUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1,
      payload: { base_temperature: 10 }
    });
  });

  it('should call updateThermalRequirementUseCase when updateThermalRequirement is called', () => {
    component.updateThermalRequirement(1, { required_gdd: 100 });
    expect(mockUpdateThermalRequirementUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1,
      payload: { required_gdd: 100 }
    });
  });

  it('should call updateSunshineRequirementUseCase when updateSunshineRequirement is called', () => {
    component.updateSunshineRequirement(1, { minimum_sunshine_hours: 4 });
    expect(mockUpdateSunshineRequirementUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1,
      payload: { minimum_sunshine_hours: 4 }
    });
  });

  it('should call updateNutrientRequirementUseCase when updateNutrientRequirement is called', () => {
    component.updateNutrientRequirement(1, { daily_uptake_n: 0.5 });
    expect(mockUpdateNutrientRequirementUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1,
      payload: { daily_uptake_n: 0.5 }
    });
  });

  it('should use current user region for non-admin updates', () => {
    mockAuthService.user.mockReturnValue({ admin: false, region: 'jp' });
    component.control = {
      loading: false,
      saving: false,
      error: null,
      formData: {
        ...initialFormData,
        name: 'Crop',
        region: 'us'
      }
    };

    component.updateCrop();

    expect(mockUpdateUseCase.execute).toHaveBeenCalledWith(
      expect.objectContaining({ region: 'jp' })
    );
  });

  it('should keep selected region for admin updates', () => {
    mockAuthService.user.mockReturnValue({ admin: true, region: 'jp' });
    component.control = {
      loading: false,
      saving: false,
      error: null,
      formData: {
        ...initialFormData,
        name: 'Crop',
        region: 'us'
      }
    };

    component.updateCrop();

    expect(mockUpdateUseCase.execute).toHaveBeenCalledWith(
      expect.objectContaining({ region: 'us' })
    );
  });

  it('should render crop stages without ngModel error after fix', () => {
    // Set up component with crop stages
    component.control = {
      loading: false,
      saving: false,
      error: null,
      formData: {
        ...initialFormData,
        crop_stages: [
          {
            id: 1,
            name: 'Stage 1',
            order: 1,
            temperature_requirement: null,
            thermal_requirement: null,
            sunshine_requirement: null,
            nutrient_requirement: null
          } as CropStage
        ]
      }
    };

    // This should not throw NG01352 error after adding name attributes
    expect(() => {
      fixture.detectChanges();
    }).not.toThrow();
  });

  it('should translate stage title with correct parameters', () => {
    // Set up component with crop stages
    component.control = {
      loading: false,
      saving: false,
      error: null,
      formData: {
        ...initialFormData,
        crop_stages: [
          {
            id: 1,
            name: 'Stage 1',
            order: 1,
            temperature_requirement: null,
            thermal_requirement: null,
            sunshine_requirement: null,
            nutrient_requirement: null
          } as CropStage
        ]
      }
    };

    fixture.detectChanges();

    // Check that translation parameters are applied for stage title
    // The component should render the translated title with the order substituted
    const stageTitleElement = fixture.nativeElement.querySelector('.crop-stage-card__title');
    expect(stageTitleElement).toBeTruthy();
    expect(stageTitleElement.textContent).toContain('ステージ 1');
  });
});