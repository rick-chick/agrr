import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { NgModel } from '@angular/forms';
import { By } from '@angular/platform-browser';
import { of } from 'rxjs';
import { vi } from 'vitest';
import { FarmCreateComponent } from './farm-create.component';
import { CreateFarmUseCase } from '../../../usecase/farms/create-farm.usecase';
import { FarmCreatePresenter } from '../../../usecase/farms/farm-create.providers';
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
      pendingErrorFlash: null,
      formData: {
        name: 'Test Farm',
        region: 'Test Region',
        latitude: 35.0,
        longitude: 135.0
      },
    };
    component.control = state;
    expect(component.control).toEqual(state);
  });

  it('calls markForCheck when control is updated', () => {
    const state: FarmCreateViewState = {
      saving: false,
      error: null,
      pendingErrorFlash: null,
      formData: {
        name: 'Test Farm',
        region: 'Test Region',
        latitude: 35.0,
        longitude: 135.0
      },
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

  it('shows master context header and omits back link from form-card__actions', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        farms: { index: { title: 'Farms' }, new: { title: 'Add New Farm' } }
      },
      true
    );
    translate.use('en');
    fixture.detectChanges();

    const backLink = fixture.nativeElement.querySelector(
      'a.master-context-header__back'
    ) as HTMLAnchorElement;
    expect(backLink?.getAttribute('href')).toBe('/farms');
    expect(fixture.nativeElement.querySelector('[aria-current="page"]')?.textContent?.trim()).toBe(
      'Add New Farm'
    );
    expect(
      fixture.nativeElement.querySelectorAll('.form-card__actions a.btn-secondary')
    ).toHaveLength(0);
  });

  it('exposes aria-invalid and aria-describedby when required name is empty on submit', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        common: { form_field: { required: 'This field is required.' } },
        farms: {
          index: { title: 'Farms' },
          new: {
            title: 'Add New Farm',
            form: {
              name_label: 'Name',
              location_label: 'Location',
              latitude_label: 'Latitude',
              longitude_label: 'Longitude',
              latitude_placeholder: '35.0',
              longitude_placeholder: '135.0',
              submit: 'Create'
            }
          },
          map: { default_name: 'Farm' }
        }
      },
      true
    );
    translate.use('en');
    fixture.detectChanges();

    const nameModel = fixture.debugElement
      .query(By.css('#name'))
      .injector.get(NgModel);
    nameModel.control.setErrors({ required: true });
    component.formSubmitted = true;
    fixture.detectChanges();

    const nameInput = fixture.nativeElement.querySelector('#name') as HTMLInputElement;
    expect(nameInput.getAttribute('aria-invalid')).toBe('true');
    expect(nameInput.getAttribute('aria-describedby')).toBe('name-error');
    expect(fixture.nativeElement.querySelector('#name-error')?.textContent?.trim()).toBe(
      'This field is required.'
    );
  });

  it('exposes aria-invalid and aria-describedby for invalid coordinates', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        common: { form_field: { required: 'This field is required.' } },
        farms: {
          index: { title: 'Farms' },
          new: {
            title: 'Add New Farm',
            form: {
              name_label: 'Name',
              location_label: 'Location',
              latitude_label: 'Latitude',
              longitude_label: 'Longitude',
              latitude_placeholder: '35.0',
              longitude_placeholder: '135.0',
              submit: 'Create',
              coordinates_validation_error: 'Invalid coordinates.'
            }
          },
          map: { default_name: 'Farm' }
        }
      },
      true
    );
    translate.use('en');
    auth.user.mockReturnValue({ admin: false, region: 'us' });
    component.fieldErrors = {
      latitude: 'farms.new.form.coordinates_validation_error',
      longitude: 'farms.new.form.coordinates_validation_error'
    };
    fixture.detectChanges();

    const latitudeInput = fixture.nativeElement.querySelector('#latitude') as HTMLInputElement;
    const longitudeInput = fixture.nativeElement.querySelector('#longitude') as HTMLInputElement;
    expect(latitudeInput.getAttribute('aria-invalid')).toBe('true');
    expect(latitudeInput.getAttribute('aria-describedby')).toBe('latitude-error');
    expect(longitudeInput.getAttribute('aria-invalid')).toBe('true');
    expect(longitudeInput.getAttribute('aria-describedby')).toBe('longitude-error');
    expect(fixture.nativeElement.querySelector('#latitude-error')?.textContent?.trim()).toBe(
      'Invalid coordinates.'
    );
  });
});