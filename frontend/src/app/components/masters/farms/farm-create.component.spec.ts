import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { of } from 'rxjs';
import { vi } from 'vitest';
import { FarmCreateComponent } from './farm-create.component';
import { CreateFarmUseCase } from '../../../usecase/farms/create-farm.usecase';
import { FarmCreatePresenter } from '../../../adapters/farms/farm-create.presenter';
import { CREATE_FARM_OUTPUT_PORT } from '../../../usecase/farms/create-farm.output-port';
import { FARM_GATEWAY } from '../../../usecase/farms/farm-gateway';
import { FarmCreateViewState } from './farm-create.view';
import { AuthService } from '../../../services/auth.service';

describe('FarmCreateComponent', () => {
  let component: FarmCreateComponent;
  let fixture: ComponentFixture<FarmCreateComponent>;
  let useCase: { execute: ReturnType<typeof vi.fn> };
  let presenter: { setView: ReturnType<typeof vi.fn> };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };
  let auth: { user: ReturnType<typeof vi.fn>; loadCurrentUser: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    useCase = { execute: vi.fn() };
    presenter = { setView: vi.fn() };
    cdr = { markForCheck: vi.fn() };
    auth = { user: vi.fn(() => null), loadCurrentUser: vi.fn(() => of(null)) };

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
            { provide: FARM_GATEWAY, useValue: {} },
            { provide: AuthService, useValue: auth }
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
    // 当テストではユーザを管理者として扱い、選択されたラベル(region)がそのまま送信されることを検証する
    auth.user.mockReturnValue({ admin: true, region: 'jp' });
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

  it('calls useCase on createFarm when form is valid', () => {
    component.control = {
      ...component.control,
      formData: {
        name: 'Test Farm',
        region: 'Test Region',
        latitude: 35.0,
        longitude: 135.0
      }
    };

    component.createFarm();

    expect(useCase.execute).toHaveBeenCalled();
  });

  it('ngOnInit sets view on presenter', () => {
    component.ngOnInit();
    expect(presenter.setView).toHaveBeenCalledWith(component);
  });

  it('uses user region for non-admin on createFarm', () => {
    auth.user.mockReturnValue({ admin: false, region: 'us' });
    component.control = {
      ...component.control,
      formData: {
        name: 'Test Farm',
        region: '',
        latitude: 35.0,
        longitude: 135.0
      }
    };

    component.createFarm();

    expect(useCase.execute).toHaveBeenCalledWith({
      name: 'Test Farm',
      region: 'us',
      latitude: 35.0,
      longitude: 135.0,
      onSuccess: expect.any(Function)
    });
  });

  it('keeps selected region for admin on createFarm', () => {
    auth.user.mockReturnValue({ admin: true, region: 'us' });
    component.control = {
      ...component.control,
      formData: {
        name: 'Admin Farm',
        region: 'jp',
        latitude: 35.0,
        longitude: 135.0
      }
    };

    component.createFarm();

    expect(useCase.execute).toHaveBeenCalledWith({
      name: 'Admin Farm',
      region: 'jp',
      latitude: 35.0,
      longitude: 135.0,
      onSuccess: expect.any(Function)
    });
  });
});