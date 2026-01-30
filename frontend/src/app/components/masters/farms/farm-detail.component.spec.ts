import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, Router } from '@angular/router';
import { FarmDetailComponent } from './farm-detail.component';
import { LoadFarmDetailUseCase } from '../../../usecase/farms/load-farm-detail.usecase';
import { SubscribeFarmWeatherUseCase } from '../../../usecase/farms/subscribe-farm-weather.usecase';
import { DeleteFarmUseCase } from '../../../usecase/farms/delete-farm.usecase';
import { CreateFieldUseCase } from '../../../usecase/farms/create-field.usecase';
import { UpdateFieldUseCase } from '../../../usecase/farms/update-field.usecase';
import { DeleteFieldUseCase } from '../../../usecase/farms/delete-field.usecase';
import { FarmDetailPresenter } from '../../../adapters/farms/farm-detail.presenter';
import { CreateFieldPresenter } from '../../../adapters/farms/create-field.presenter';
import { UpdateFieldPresenter } from '../../../adapters/farms/update-field.presenter';
import { DeleteFieldPresenter } from '../../../adapters/farms/delete-field.presenter';
import { FarmDetailViewState } from './farm-detail.view';
import { Field } from '../../../domain/farms/field';

describe('FarmDetailComponent', () => {
  let component: FarmDetailComponent;
  let fixture: ComponentFixture<FarmDetailComponent>;
  let loadUseCase: { execute: jest.Mock };
  let subscribeWeatherUseCase: { execute: jest.Mock };
  let deleteUseCase: { execute: jest.Mock };
  let createFieldUseCase: { execute: jest.Mock };
  let updateFieldUseCase: { execute: jest.Mock };
  let deleteFieldUseCase: { execute: jest.Mock };
  let presenter: { setView: jest.Mock };
  let createFieldPresenter: { setView: jest.Mock };
  let updateFieldPresenter: { setView: jest.Mock };
  let deleteFieldPresenter: { setView: jest.Mock };
  let cdr: { markForCheck: jest.Mock };
  let router: { navigate: jest.Mock };

  beforeEach(async () => {
    loadUseCase = { execute: jest.fn() };
    subscribeWeatherUseCase = { execute: jest.fn() };
    deleteUseCase = { execute: jest.fn() };
    createFieldUseCase = { execute: jest.fn() };
    updateFieldUseCase = { execute: jest.fn() };
    deleteFieldUseCase = { execute: jest.fn() };
    presenter = { setView: jest.fn() };
    createFieldPresenter = { setView: jest.fn() };
    updateFieldPresenter = { setView: jest.fn() };
    deleteFieldPresenter = { setView: jest.fn() };
    cdr = { markForCheck: jest.fn() };
    router = { navigate: jest.fn() };

    await TestBed.configureTestingModule({
      imports: [FarmDetailComponent],
      providers: [
        { provide: ActivatedRoute, useValue: { snapshot: { paramMap: { get: () => '123' } } } },
        { provide: Router, useValue: router },
        { provide: LoadFarmDetailUseCase, useValue: loadUseCase },
        { provide: SubscribeFarmWeatherUseCase, useValue: subscribeWeatherUseCase },
        { provide: DeleteFarmUseCase, useValue: deleteUseCase },
        { provide: CreateFieldUseCase, useValue: createFieldUseCase },
        { provide: UpdateFieldUseCase, useValue: updateFieldUseCase },
        { provide: DeleteFieldUseCase, useValue: deleteFieldUseCase },
        { provide: FarmDetailPresenter, useValue: presenter },
        { provide: CreateFieldPresenter, useValue: createFieldPresenter },
        { provide: UpdateFieldPresenter, useValue: updateFieldPresenter },
        { provide: DeleteFieldPresenter, useValue: deleteFieldPresenter }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(FarmDetailComponent);
    component = fixture.componentInstance;

    // Replace ChangeDetectorRef with mock
    Object.defineProperty(component, 'cdr', { value: cdr });
  });

  it('implements View control getter/setter', () => {
    const state: FarmDetailViewState = {
      loading: false,
      error: null,
      farm: null,
      fields: []
    };
    component.control = state;
    expect(component.control).toEqual(state);
  });

  it('calls markForCheck when control is updated', () => {
    const state: FarmDetailViewState = {
      loading: false,
      error: null,
      farm: null,
      fields: []
    };
    component.control = state;
    expect(cdr.markForCheck).toHaveBeenCalled();
  });

  it('calls useCases.execute on load', () => {
    const farmId = 123;
    component.load(farmId);
    expect(loadUseCase.execute).toHaveBeenCalledWith({ farmId });
    expect(subscribeWeatherUseCase.execute).toHaveBeenCalledWith({
      farmId,
      onSubscribed: expect.any(Function)
    });
  });

  it('calls deleteUseCase.execute on deleteFarm', () => {
    const farm = { id: 123, name: 'Test Farm', region: 'Test Region', latitude: 0, longitude: 0 };
    component.control = { ...component.control, farm };

    component.deleteFarm();
    expect(deleteUseCase.execute).toHaveBeenCalledWith({
      farmId: 123,
      onSuccess: expect.any(Function)
    });
  });

  it('calls createFieldUseCase.execute on addField with valid inputs', () => {
    const farm = { id: 123, name: 'Test Farm', region: 'Test Region', latitude: 0, longitude: 0 };
    component.control = { ...component.control, farm };

    const promptSpy = jest.spyOn(window, 'prompt');
    promptSpy.mockReturnValueOnce('Field Name'); // name
    promptSpy.mockReturnValueOnce('10'); // area
    promptSpy.mockReturnValueOnce('100'); // dailyFixedCost
    promptSpy.mockReturnValueOnce('Region'); // region

    component.addField();
    expect(createFieldUseCase.execute).toHaveBeenCalledWith({
      farmId: 123,
      payload: {
        name: 'Field Name',
        area: 10,
        daily_fixed_cost: 100,
        region: 'Region'
      }
    });

    promptSpy.mockRestore();
  });

  it('calls updateFieldUseCase.execute on editField with valid inputs', () => {
    const field: Field = {
      id: 456,
      name: 'Old Name',
      area: 5,
      daily_fixed_cost: 50,
      region: 'Old Region'
    };

    const promptSpy = jest.spyOn(window, 'prompt');
    promptSpy.mockReturnValueOnce('New Name'); // name
    promptSpy.mockReturnValueOnce('15'); // area
    promptSpy.mockReturnValueOnce('150'); // dailyFixedCost
    promptSpy.mockReturnValueOnce('New Region'); // region

    component.editField(field);
    expect(updateFieldUseCase.execute).toHaveBeenCalledWith({
      fieldId: 456,
      payload: {
        name: 'New Name',
        area: 15,
        daily_fixed_cost: 150,
        region: 'New Region'
      }
    });

    promptSpy.mockRestore();
  });

  it('calls deleteFieldUseCase.execute on deleteField', () => {
    const farm = { id: 123, name: 'Test Farm', region: 'Test Region', latitude: 0, longitude: 0 };
    component.control = { ...component.control, farm };

    const field: Field = { id: 456, name: 'Test Field' };

    component.deleteField(field);
    expect(deleteFieldUseCase.execute).toHaveBeenCalledWith({
      fieldId: 456,
      farmId: 123
    });
  });

  it('ngOnInit sets views on presenters and calls load with route param', () => {
    component.ngOnInit();
    expect(presenter.setView).toHaveBeenCalledWith(component);
    expect(createFieldPresenter.setView).toHaveBeenCalledWith(component);
    expect(updateFieldPresenter.setView).toHaveBeenCalledWith(component);
    expect(deleteFieldPresenter.setView).toHaveBeenCalledWith(component);
    expect(loadUseCase.execute).toHaveBeenCalledWith({ farmId: 123 });
  });

  it('ngOnInit sets error for invalid farm id', () => {
    // Mock invalid id
    Object.defineProperty(component, 'route', {
      value: { snapshot: { paramMap: { get: () => null } } }
    });

    component.ngOnInit();
    expect(component.control.error).toBe('Invalid farm id.');
    expect(component.control.loading).toBe(false);
  });

  it('trackByFieldId returns field id', () => {
    const field: Field = { id: 456, name: 'Test Field' };
    expect(component.trackByFieldId(0, field)).toBe(456);
  });
});