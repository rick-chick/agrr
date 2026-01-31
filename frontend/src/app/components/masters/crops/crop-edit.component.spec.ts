import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute } from '@angular/router';
import { of } from 'rxjs';

import { CropEditComponent } from './crop-edit.component';
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
  let mockLoadUseCase: jasmine.SpyObj<LoadCropForEditUseCase>;
  let mockUpdateUseCase: jasmine.SpyObj<UpdateCropUseCase>;
  let mockCreateCropStageUseCase: jasmine.SpyObj<CreateCropStageUseCase>;
  let mockUpdateCropStageUseCase: jasmine.SpyObj<UpdateCropStageUseCase>;
  let mockDeleteCropStageUseCase: jasmine.SpyObj<DeleteCropStageUseCase>;
  let mockUpdateTemperatureRequirementUseCase: jasmine.SpyObj<UpdateTemperatureRequirementUseCase>;
  let mockUpdateThermalRequirementUseCase: jasmine.SpyObj<UpdateThermalRequirementUseCase>;
  let mockUpdateSunshineRequirementUseCase: jasmine.SpyObj<UpdateSunshineRequirementUseCase>;
  let mockUpdateNutrientRequirementUseCase: jasmine.SpyObj<UpdateNutrientRequirementUseCase>;

  beforeEach(async () => {
    mockActivatedRoute = {
      snapshot: {
        paramMap: {
          get: jasmine.createSpy('get').and.returnValue('1')
        }
      }
    };

    mockLoadUseCase = jasmine.createSpyObj('LoadCropForEditUseCase', ['execute']);
    mockUpdateUseCase = jasmine.createSpyObj('UpdateCropUseCase', ['execute']);
    mockCreateCropStageUseCase = jasmine.createSpyObj('CreateCropStageUseCase', ['execute']);
    mockUpdateCropStageUseCase = jasmine.createSpyObj('UpdateCropStageUseCase', ['execute']);
    mockDeleteCropStageUseCase = jasmine.createSpyObj('DeleteCropStageUseCase', ['execute']);
    mockUpdateTemperatureRequirementUseCase = jasmine.createSpyObj('UpdateTemperatureRequirementUseCase', ['execute']);
    mockUpdateThermalRequirementUseCase = jasmine.createSpyObj('UpdateThermalRequirementUseCase', ['execute']);
    mockUpdateSunshineRequirementUseCase = jasmine.createSpyObj('UpdateSunshineRequirementUseCase', ['execute']);
    mockUpdateNutrientRequirementUseCase = jasmine.createSpyObj('UpdateNutrientRequirementUseCase', ['execute']);

    await TestBed.configureTestingModule({
      imports: [CropEditComponent],
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
        { provide: UpdateNutrientRequirementUseCase, useValue: mockUpdateNutrientRequirementUseCase }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(CropEditComponent);
    component = fixture.componentInstance;
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should load crop on init', () => {
    component.ngOnInit();
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
    spyOn(window, 'confirm').and.returnValue(true);
    component.deleteCropStage(1);
    expect(mockDeleteCropStageUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1
    });
  });

  it('should not call deleteCropStageUseCase when deleteCropStage is cancelled', () => {
    spyOn(window, 'confirm').and.returnValue(false);
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
});