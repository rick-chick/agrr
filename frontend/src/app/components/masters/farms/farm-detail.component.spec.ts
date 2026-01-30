import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, Router } from '@angular/router';
import { provideRouter } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { vi } from 'vitest';
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
import { LOAD_FARM_DETAIL_OUTPUT_PORT } from '../../../usecase/farms/load-farm-detail.output-port';
import { SUBSCRIBE_FARM_WEATHER_OUTPUT_PORT } from '../../../usecase/farms/subscribe-farm-weather.output-port';
import { DELETE_FARM_OUTPUT_PORT } from '../../../usecase/farms/delete-farm.output-port';
import { CREATE_FIELD_OUTPUT_PORT } from '../../../usecase/farms/create-field.output-port';
import { UPDATE_FIELD_OUTPUT_PORT } from '../../../usecase/farms/update-field.output-port';
import { DELETE_FIELD_OUTPUT_PORT } from '../../../usecase/farms/delete-field.output-port';
import { FARM_GATEWAY } from '../../../usecase/farms/farm-gateway';
import { FARM_WEATHER_GATEWAY } from '../../../usecase/farms/farm-weather-gateway';
import { FarmDetailViewState } from './farm-detail.view';
import { Field } from '../../../domain/farms/field';

describe('FarmDetailComponent', () => {
  let component: FarmDetailComponent;
  let fixture: ComponentFixture<FarmDetailComponent>;
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let subscribeWeatherUseCase: { execute: ReturnType<typeof vi.fn> };
  let deleteUseCase: { execute: ReturnType<typeof vi.fn> };
  let createFieldUseCase: { execute: ReturnType<typeof vi.fn> };
  let updateFieldUseCase: { execute: ReturnType<typeof vi.fn> };
  let deleteFieldUseCase: { execute: ReturnType<typeof vi.fn> };
  let presenter: { setView: ReturnType<typeof vi.fn> };
  let createFieldPresenter: { setView: ReturnType<typeof vi.fn> };
  let updateFieldPresenter: { setView: ReturnType<typeof vi.fn> };
  let deleteFieldPresenter: { setView: ReturnType<typeof vi.fn> };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    loadUseCase = { execute: vi.fn() };
    subscribeWeatherUseCase = { execute: vi.fn() };
    deleteUseCase = { execute: vi.fn() };
    createFieldUseCase = { execute: vi.fn() };
    updateFieldUseCase = { execute: vi.fn() };
    deleteFieldUseCase = { execute: vi.fn() };
    presenter = { setView: vi.fn() };
    createFieldPresenter = { setView: vi.fn() };
    updateFieldPresenter = { setView: vi.fn() };
    deleteFieldPresenter = { setView: vi.fn() };
    cdr = { markForCheck: vi.fn() };

    await TestBed.configureTestingModule({
      imports: [FarmDetailComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: ActivatedRoute, useValue: { snapshot: { paramMap: { get: () => '123' } } } }
      ]
    })
      .overrideComponent(FarmDetailComponent, {
        set: {
          providers: [
            { provide: LoadFarmDetailUseCase, useValue: loadUseCase },
            { provide: SubscribeFarmWeatherUseCase, useValue: subscribeWeatherUseCase },
            { provide: DeleteFarmUseCase, useValue: deleteUseCase },
            { provide: CreateFieldUseCase, useValue: createFieldUseCase },
            { provide: UpdateFieldUseCase, useValue: updateFieldUseCase },
            { provide: DeleteFieldUseCase, useValue: deleteFieldUseCase },
            { provide: FarmDetailPresenter, useValue: presenter },
            { provide: CreateFieldPresenter, useValue: createFieldPresenter },
            { provide: UpdateFieldPresenter, useValue: updateFieldPresenter },
            { provide: DeleteFieldPresenter, useValue: deleteFieldPresenter },
            { provide: LOAD_FARM_DETAIL_OUTPUT_PORT, useExisting: FarmDetailPresenter },
            { provide: SUBSCRIBE_FARM_WEATHER_OUTPUT_PORT, useExisting: FarmDetailPresenter },
            { provide: DELETE_FARM_OUTPUT_PORT, useExisting: FarmDetailPresenter },
            { provide: CREATE_FIELD_OUTPUT_PORT, useExisting: CreateFieldPresenter },
            { provide: UPDATE_FIELD_OUTPUT_PORT, useExisting: UpdateFieldPresenter },
            { provide: DELETE_FIELD_OUTPUT_PORT, useExisting: DeleteFieldPresenter },
            { provide: FARM_GATEWAY, useValue: {} },
            { provide: FARM_WEATHER_GATEWAY, useValue: {} }
          ]
        }
      })
      .compileComponents();

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

    const promptSpy = vi.spyOn(window, 'prompt');
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
      farm_id: 1,
      user_id: null,
      name: 'Old Name',
      description: null,
      area: 5,
      daily_fixed_cost: 50,
      region: 'Old Region',
      created_at: '2023-01-01',
      updated_at: '2023-01-01'
    };

    const promptSpy = vi.spyOn(window, 'prompt');
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

    const field: Field = {
      id: 456,
      farm_id: 123,
      user_id: null,
      name: 'Test Field',
      description: null,
      area: 100,
      daily_fixed_cost: 50,
      region: 'Region',
      created_at: '2023-01-01',
      updated_at: '2023-01-01'
    };

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

  it('ngOnInit does not call load when farm id is invalid', () => {
    vi.mocked(loadUseCase.execute).mockClear();
    Object.defineProperty(component, 'route', {
      value: { snapshot: { paramMap: { get: () => null } } }
    });

    component.ngOnInit();
    expect(loadUseCase.execute).not.toHaveBeenCalled();
  });

  it('trackByFieldId returns field id', () => {
    const field: Field = {
      id: 456,
      farm_id: 1,
      user_id: null,
      name: 'Test Field',
      description: null,
      area: 100,
      daily_fixed_cost: 50,
      region: 'Region',
      created_at: '2023-01-01',
      updated_at: '2023-01-01'
    };
    expect(component.trackByFieldId(0, field)).toBe(456);
  });
});