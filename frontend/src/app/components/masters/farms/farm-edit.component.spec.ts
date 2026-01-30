import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute } from '@angular/router';
import { provideRouter } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { vi } from 'vitest';
import { FarmEditComponent } from './farm-edit.component';
import { LoadFarmForEditUseCase } from '../../../usecase/farms/load-farm-for-edit.usecase';
import { UpdateFarmUseCase } from '../../../usecase/farms/update-farm.usecase';
import { FarmEditPresenter } from '../../../adapters/farms/farm-edit.presenter';
import { LOAD_FARM_FOR_EDIT_OUTPUT_PORT } from '../../../usecase/farms/load-farm-for-edit.output-port';
import { UPDATE_FARM_OUTPUT_PORT } from '../../../usecase/farms/update-farm.output-port';
import { FARM_GATEWAY } from '../../../usecase/farms/farm-gateway';
import { FarmEditViewState } from './farm-edit.view';

describe('FarmEditComponent', () => {
  let component: FarmEditComponent;
  let fixture: ComponentFixture<FarmEditComponent>;
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let updateUseCase: { execute: ReturnType<typeof vi.fn> };
  let presenter: { setView: ReturnType<typeof vi.fn> };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    loadUseCase = { execute: vi.fn() };
    updateUseCase = { execute: vi.fn() };
    presenter = { setView: vi.fn() };
    cdr = { markForCheck: vi.fn() };

    await TestBed.configureTestingModule({
      imports: [FarmEditComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: ActivatedRoute, useValue: { snapshot: { paramMap: { get: () => '123' } } } }
      ]
    })
      .overrideComponent(FarmEditComponent, {
        set: {
          providers: [
            { provide: LoadFarmForEditUseCase, useValue: loadUseCase },
            { provide: UpdateFarmUseCase, useValue: updateUseCase },
            { provide: FarmEditPresenter, useValue: presenter },
            { provide: LOAD_FARM_FOR_EDIT_OUTPUT_PORT, useExisting: FarmEditPresenter },
            { provide: UPDATE_FARM_OUTPUT_PORT, useExisting: FarmEditPresenter },
            { provide: FARM_GATEWAY, useValue: {} }
          ]
        }
      })
      .compileComponents();

    fixture = TestBed.createComponent(FarmEditComponent);
    component = fixture.componentInstance;

    // Replace ChangeDetectorRef with mock
    Object.defineProperty(component, 'cdr', { value: cdr });
  });

  it('implements View control getter/setter', () => {
    const state: FarmEditViewState = {
      loading: false,
      saving: false,
      error: null,
      formData: {
        name: 'Test Farm',
        region: 'Test Region',
        latitude: 35.0,
        longitude: 135.0
      }
    };
    component.control = state;
    expect(component.control).toEqual(state);
  });

  it('calls markForCheck when control is updated', () => {
    const state: FarmEditViewState = {
      loading: false,
      saving: false,
      error: null,
      formData: {
        name: 'Test Farm',
        region: 'Test Region',
        latitude: 35.0,
        longitude: 135.0
      }
    };
    component.control = state;
    expect(cdr.markForCheck).toHaveBeenCalled();
  });

  it('calls updateUseCase.execute on updateFarm with form data and farmId', () => {
    const formData = {
      name: 'Updated Farm',
      region: 'Updated Region',
      latitude: 36.0,
      longitude: 136.0
    };
    component.control = { ...component.control, formData };

    component.updateFarm();
    expect(updateUseCase.execute).toHaveBeenCalledWith({
      farmId: 123,
      name: 'Updated Farm',
      region: 'Updated Region',
      latitude: 36.0,
      longitude: 136.0,
      onSuccess: expect.any(Function)
    });
  });

  it('calls updateUseCase on updateFarm when form is valid', () => {
    component.control = {
      ...component.control,
      formData: {
        name: 'Test Farm',
        region: 'Test Region',
        latitude: 35.0,
        longitude: 135.0
      }
    };

    component.updateFarm();

    expect(updateUseCase.execute).toHaveBeenCalled();
  });

  it('ngOnInit sets view on presenter and calls loadUseCase with farmId', () => {
    component.ngOnInit();
    expect(presenter.setView).toHaveBeenCalledWith(component);
    expect(loadUseCase.execute).toHaveBeenCalledWith({ farmId: 123 });
  });

  it('ngOnInit does not call loadUseCase when farm id is invalid', async () => {
    vi.mocked(loadUseCase.execute).mockClear();
    await TestBed.resetTestingModule()
      .configureTestingModule({
        imports: [FarmEditComponent, TranslateModule.forRoot()],
        providers: [
          provideRouter([]),
          { provide: ActivatedRoute, useValue: { snapshot: { paramMap: { get: () => null } } } }
        ]
      })
      .overrideComponent(FarmEditComponent, {
        set: {
          providers: [
            { provide: LoadFarmForEditUseCase, useValue: loadUseCase },
            { provide: UpdateFarmUseCase, useValue: updateUseCase },
            { provide: FarmEditPresenter, useValue: presenter },
            { provide: LOAD_FARM_FOR_EDIT_OUTPUT_PORT, useExisting: FarmEditPresenter },
            { provide: UPDATE_FARM_OUTPUT_PORT, useExisting: FarmEditPresenter },
            { provide: FARM_GATEWAY, useValue: {} }
          ]
        }
      })
      .compileComponents();

    const fixtureWithInvalidId = TestBed.createComponent(FarmEditComponent);
    const comp = fixtureWithInvalidId.componentInstance;
    Object.defineProperty(comp, 'cdr', { value: cdr });

    comp.ngOnInit();
    expect(loadUseCase.execute).not.toHaveBeenCalled();
  });

  it('farmId getter returns parsed route param', () => {
    expect(component['farmId']).toBe(123);
  });

  it('farmId getter returns NaN for invalid param', () => {
    Object.defineProperty(component, 'route', {
      value: { snapshot: { paramMap: { get: () => 'invalid' } } }
    });

    expect(Number.isNaN(component['farmId'])).toBe(true);
  });
});