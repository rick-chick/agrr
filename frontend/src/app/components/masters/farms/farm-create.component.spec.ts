import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { vi } from 'vitest';
import { FarmCreateComponent } from './farm-create.component';
import { CreateFarmUseCase } from '../../../usecase/farms/create-farm.usecase';
import { FarmCreatePresenter } from '../../../adapters/farms/farm-create.presenter';
import { CREATE_FARM_OUTPUT_PORT } from '../../../usecase/farms/create-farm.output-port';
import { FARM_GATEWAY } from '../../../usecase/farms/farm-gateway';
import { FarmCreateViewState } from './farm-create.view';

describe('FarmCreateComponent', () => {
  let component: FarmCreateComponent;
  let fixture: ComponentFixture<FarmCreateComponent>;
  let useCase: { execute: ReturnType<typeof vi.fn> };
  let presenter: { setView: ReturnType<typeof vi.fn> };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    useCase = { execute: vi.fn() };
    presenter = { setView: vi.fn() };
    cdr = { markForCheck: vi.fn() };

    await TestBed.configureTestingModule({
      imports: [FarmCreateComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    })
      .overrideComponent(FarmCreateComponent, {
        set: {
          providers: [
            { provide: CreateFarmUseCase, useValue: useCase },
            { provide: FarmCreatePresenter, useValue: presenter },
            { provide: CREATE_FARM_OUTPUT_PORT, useExisting: FarmCreatePresenter },
            { provide: FARM_GATEWAY, useValue: {} }
          ]
        }
      })
      .compileComponents();

    fixture = TestBed.createComponent(FarmCreateComponent);
    component = fixture.componentInstance;

    // Replace ChangeDetectorRef with mock
    Object.defineProperty(component, 'cdr', { value: cdr });
  });

  it('implements View control getter/setter', () => {
    const state: FarmCreateViewState = {
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
    const state: FarmCreateViewState = {
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

  it('calls useCase.execute on createFarm with form data', () => {
    const formData = {
      name: 'Test Farm',
      region: 'Test Region',
      latitude: 35.0,
      longitude: 135.0
    };
    component.control = { ...component.control, formData };

    component.createFarm();
    expect(useCase.execute).toHaveBeenCalledWith({
      name: 'Test Farm',
      region: 'Test Region',
      latitude: 35.0,
      longitude: 135.0,
      onSuccess: expect.any(Function)
    });
  });

  it('clears error on createFarm before calling useCase', () => {
    component.control = {
      ...component.control,
      error: 'Previous error',
      formData: {
        name: 'Test Farm',
        region: 'Test Region',
        latitude: 35.0,
        longitude: 135.0
      }
    };

    component.createFarm();

    expect(component.control.error).toBe(null);
    expect(useCase.execute).toHaveBeenCalled();
  });

  it('ngOnInit sets view on presenter', () => {
    component.ngOnInit();
    expect(presenter.setView).toHaveBeenCalledWith(component);
  });
});