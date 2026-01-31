import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute } from '@angular/router';
import { of } from 'rxjs';
import { vi } from 'vitest';
import { PesticideEditComponent } from './pesticide-edit.component';
import { LoadPesticideForEditUseCase } from '../../../usecase/pesticides/load-pesticide-for-edit.usecase';
import { UpdatePesticideUseCase } from '../../../usecase/pesticides/update-pesticide.usecase';
import { PesticideEditViewState } from './pesticide-edit.view';
import { PesticideEditPresenter } from '../../../adapters/pesticides/pesticide-edit.presenter';
import { CROP_GATEWAY } from '../../../usecase/crops/crop-gateway';
import { PEST_GATEWAY } from '../../../usecase/pests/pest-gateway';

describe('PesticideEditComponent', () => {
  let component: PesticideEditComponent;
  let fixture: ComponentFixture<PesticideEditComponent>;
  let mockActivatedRoute: any;
  let mockLoadUseCase: any;
  let mockUpdateUseCase: any;
  let mockCropGateway: any;
  let mockPestGateway: any;

  beforeEach(async () => {
    mockActivatedRoute = {
      snapshot: {
        paramMap: {
          get: () => '123'
        }
      }
    };

    mockLoadUseCase = { execute: vi.fn(() => of(undefined)) };
    mockUpdateUseCase = { execute: vi.fn(() => of(undefined)) };
    mockCropGateway = { list: vi.fn(() => of([])) };
    mockPestGateway = { list: vi.fn(() => of([])) };

    await TestBed.configureTestingModule({
      imports: [PesticideEditComponent],
      providers: [
        PesticideEditPresenter,
        { provide: ActivatedRoute, useValue: mockActivatedRoute },
        { provide: LoadPesticideForEditUseCase, useValue: mockLoadUseCase },
        { provide: UpdatePesticideUseCase, useValue: mockUpdateUseCase },
        { provide: CROP_GATEWAY, useValue: mockCropGateway },
        { provide: PEST_GATEWAY, useValue: mockPestGateway }
      ]
    })
    .overrideComponent(PesticideEditComponent, {
      set: {
        providers: [
          { provide: LoadPesticideForEditUseCase, useValue: mockLoadUseCase },
          { provide: UpdatePesticideUseCase, useValue: mockUpdateUseCase },
          { provide: CROP_GATEWAY, useValue: mockCropGateway },
          { provide: PEST_GATEWAY, useValue: mockPestGateway }
        ]
      }
    })
    .compileComponents();

    fixture = TestBed.createComponent(PesticideEditComponent);
    component = fixture.componentInstance;
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('implements View control getter/setter', () => {
    const state: PesticideEditViewState = {
      loading: false,
      saving: false,
      error: null,
      formData: {
        name: 'Test Pesticide',
        active_ingredient: 'Test Ingredient',
        description: 'Test Description',
        crop_id: 1,
        pest_id: 1,
        region: 'jp'
      }
    };
    component.control = state;
    expect(component.control).toEqual(state);
  });

  it('calls loadUseCase.execute with correct params on load', () => {
    // First ensure component is properly initialized
    expect(component).toBeTruthy();
    expect(typeof component.load).toBe('function');
    component.load(123);
    expect(mockLoadUseCase.execute).toHaveBeenCalledWith({ pesticideId: 123 });
  });

  it('ngOnInit calls load with route param', () => {
    fixture.detectChanges();
    expect(mockLoadUseCase.execute).toHaveBeenCalledWith(expect.objectContaining({ pesticideId: 123 }));
  });

  it('calls updateUseCase.execute with correct params on updatePesticide', () => {
    // Set up valid form data
    component.control = {
      loading: false,
      saving: false,
      error: null,
      formData: {
        name: 'Test Pesticide',
        active_ingredient: 'Test Ingredient',
        description: 'Test Description',
        crop_id: 1,
        pest_id: 1,
        region: 'jp'
      }
    };

    component.updatePesticide();
    expect(mockUpdateUseCase.execute).toHaveBeenCalledWith({
      pesticideId: 123,
      name: 'Test Pesticide',
      active_ingredient: 'Test Ingredient',
      description: 'Test Description',
      crop_id: 1,
      pest_id: 1,
      region: 'jp',
      onSuccess: expect.any(Function)
    });
  });

  it('does not call updateUseCase.execute when form is invalid', () => {
    // Set up invalid form data (empty name)
    component.control = {
      loading: false,
      saving: false,
      error: null,
      formData: {
        name: '',
        active_ingredient: 'Test Ingredient',
        description: 'Test Description',
        crop_id: 1,
        pest_id: 1,
        region: 'jp'
      }
    };

    component.updatePesticide();
    expect(mockUpdateUseCase.execute).not.toHaveBeenCalled();
  });

  it('sets saving state during update', () => {
    // Set up valid form data
    component.control = {
      loading: false,
      saving: false,
      error: null,
      formData: {
        name: 'Test Pesticide',
        active_ingredient: 'Test Ingredient',
        description: 'Test Description',
        crop_id: 1,
        pest_id: 1,
        region: 'jp'
      }
    };

    component.updatePesticide();
    expect(component.control.saving).toBe(true);
  });

  it('loads crops and pests on init', () => {
    fixture.detectChanges();
    expect(mockCropGateway.list).toHaveBeenCalled();
    expect(mockPestGateway.list).toHaveBeenCalled();
  });
});