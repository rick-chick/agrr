import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute } from '@angular/router';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { vi } from 'vitest';
import { FarmDetailComponent } from './farm-detail.component';
import { LoadFarmDetailUseCase } from '../../../usecase/farms/load-farm-detail.usecase';
import { SubscribeFarmWeatherUseCase } from '../../../usecase/farms/subscribe-farm-weather.usecase';
import { DeleteFarmUseCase } from '../../../usecase/farms/delete-farm.usecase';
import { CreateFieldUseCase } from '../../../usecase/farms/create-field.usecase';
import { UpdateFieldUseCase } from '../../../usecase/farms/update-field.usecase';
import { DeleteFieldUseCase } from '../../../usecase/farms/delete-field.usecase';
import {
  CreateFieldPresenter,
  DeleteFieldPresenter,
  FarmDetailPresenter,
  UpdateFieldPresenter
} from '../../../usecase/farms/farm-detail.providers';
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
import { AuthService } from '../../../services/auth.service';

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
  let auth: { user: ReturnType<typeof vi.fn> };
  let translate: TranslateService;

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
    auth = { user: vi.fn(() => null) };

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
            { provide: FARM_WEATHER_GATEWAY, useValue: {} },
            { provide: AuthService, useValue: auth }
          ]
        }
      })
      .compileComponents();

    fixture = TestBed.createComponent(FarmDetailComponent);
    component = fixture.componentInstance;
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('ja', {
      farms: {
        show: { location: '地域' },
        form: {
          region_blank: '未選択',
          region_jp: '日本'
        }
      }
    });
    translate.use('ja');

    // Replace ChangeDetectorRef with mock
    Object.defineProperty(component, 'cdr', { value: cdr });
  });

  it('implements View control getter/setter', () => {
    const state: FarmDetailViewState = {
      loading: false,
      error: null,
      farm: null,
      fields: [],
      pendingUndoToast: null,
        pendingErrorFlash: null
    };
    component.control = state;
    expect(component.control).toEqual(state);
  });

  it('calls markForCheck when control is updated', () => {
    const state: FarmDetailViewState = {
      loading: false,
      error: null,
      farm: null,
      fields: [],
      pendingUndoToast: null,
        pendingErrorFlash: null
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

  it('calls deleteUseCase.execute on deleteFarm when farm exists', () => {
    const farm = { id: 123, name: 'Test Farm', region: 'Test Region', latitude: 0, longitude: 0 };
    component.control = { ...component.control, farm };

    component.deleteFarm();
    expect(deleteUseCase.execute).toHaveBeenCalledWith({
      farmId: 123,
      onSuccess: expect.any(Function)
    });
  });

  it('calls createFieldUseCase.execute on submitFieldForm with valid inputs for admin', () => {
    auth.user.mockReturnValue({ admin: true, region: 'us' });
    const farm = { id: 123, name: 'Test Farm', region: 'jp', latitude: 0, longitude: 0 };
    component.control = { ...component.control, farm };
    component.editingField = null;
    component.fieldFormModel = {
      name: 'Field Name',
      area: 10,
      daily_fixed_cost: 100,
      region: 'jp'
    };

    component.submitFieldForm();
    expect(createFieldUseCase.execute).toHaveBeenCalledWith({
      farmId: 123,
      payload: {
        name: 'Field Name',
        area: 10,
        daily_fixed_cost: 100,
        region: 'jp'
      }
    });
  });

  it('uses user region for non-admin on submitFieldForm', () => {
    auth.user.mockReturnValue({ admin: false, region: 'us' });
    const farm = { id: 123, name: 'Test Farm', region: 'jp', latitude: 0, longitude: 0 };
    component.control = { ...component.control, farm };
    component.editingField = null;
    component.fieldFormModel = {
      name: 'Field Name',
      area: 10,
      daily_fixed_cost: 100,
      region: ''
    };

    component.submitFieldForm();
    expect(createFieldUseCase.execute).toHaveBeenCalledWith({
      farmId: 123,
      payload: {
        name: 'Field Name',
        area: 10,
        daily_fixed_cost: 100,
        region: 'us'
      }
    });
  });

  it('defaults region from farm when opening create field form', () => {
    const farm = { id: 123, name: 'Test Farm', region: 'jp', latitude: 0, longitude: 0 };
    component.control = { ...component.control, farm };

    component.openFieldForm();

    expect(component.fieldFormModel.region).toBe('jp');
  });

  it('renders field form dialog with shared form layout classes', () => {
    const farm = { id: 123, name: 'Test Farm', region: 'jp', latitude: 0, longitude: 0 };
    component.control = { ...component.control, farm, loading: false };
    fixture.detectChanges();

    const dialog = fixture.nativeElement.querySelector('dialog.form-dialog');
    expect(dialog).toBeTruthy();
    expect(fixture.nativeElement.querySelectorAll('.form-card__field')).toHaveLength(3);
    expect(fixture.nativeElement.querySelector('.form-card__actions .btn-primary')).toBeTruthy();
  });

  it('shows region select for admin in field form', () => {
    auth.user.mockReturnValue({ admin: true, region: 'jp' });
    const farm = { id: 123, name: 'Test Farm', region: 'jp', latitude: 0, longitude: 0 };
    component.control = { ...component.control, farm, loading: false };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-region-select')).toBeTruthy();
  });

  it('hides region select for non-admin in field form', () => {
    auth.user.mockReturnValue({ admin: false, region: 'jp' });
    const farm = { id: 123, name: 'Test Farm', region: 'jp', latitude: 0, longitude: 0 };
    component.control = { ...component.control, farm, loading: false };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-region-select')).toBeFalsy();
  });

  it('renders region blank label when farm region is null', () => {
    component.control = {
      loading: false,
      error: null,
      farm: { id: 123, name: 'テスト', region: null, latitude: 35.0, longitude: 139.0 },
      fields: [],
      pendingUndoToast: null,
        pendingErrorFlash: null
    };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).not.toContain('farms.form.region_null');
    expect(text).toContain('未選択');
  });

  it('renders translated region label for known region code', () => {
    component.control = {
      loading: false,
      error: null,
      farm: { id: 123, name: 'テスト', region: 'jp', latitude: 35.0, longitude: 139.0 },
      fields: [],
      pendingUndoToast: null,
        pendingErrorFlash: null
    };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('日本');
    expect(text).not.toContain('region_jp');
  });

  it('calls updateFieldUseCase.execute on submitFieldForm when editing', () => {
    auth.user.mockReturnValue({ admin: true, region: 'jp' });
    const farm = { id: 123, name: 'Test Farm', region: 'jp', latitude: 0, longitude: 0 };
    const field: Field = {
      id: 456,
      farm_id: 1,
      user_id: null,
      name: 'Old Name',
      description: null,
      area: 5,
      daily_fixed_cost: 50,
      region: 'jp',
      created_at: '2023-01-01',
      updated_at: '2023-01-01'
    };
    component.control = { ...component.control, farm };
    component.editingField = field;
    component.fieldFormModel = {
      name: 'New Name',
      area: 15,
      daily_fixed_cost: 150,
      region: 'us'
    };

    component.submitFieldForm();
    expect(updateFieldUseCase.execute).toHaveBeenCalledWith({
      fieldId: 456,
      payload: {
        name: 'New Name',
        area: 15,
        daily_fixed_cost: 150,
        region: 'us'
      }
    });
  });

  it('calls deleteFieldUseCase.execute on deleteField', () => {
    const farm = { id: 123, name: 'Test Farm', region: 'Test Region', latitude: 0, longitude: 0 };
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
    component.control = { ...component.control, farm };

    component.deleteField(field);
    expect(deleteFieldUseCase.execute).toHaveBeenCalledWith({
      fieldId: 456,
      farmId: 123
    });
  });

  it('polls farm detail while weather fetch is in progress', () => {
    vi.useFakeTimers();
    try {
      component.control = {
        loading: false,
        error: null,
        farm: {
          id: 123,
          name: 'Test Farm',
          region: 'jp',
          latitude: 35.0,
          longitude: 139.0,
          weather_data_status: 'fetching',
          weather_data_progress: 10
        },
        fields: [],
        pendingUndoToast: null,
        pendingErrorFlash: null
      };
      loadUseCase.execute.mockClear();

      vi.advanceTimersByTime(3000);
      expect(loadUseCase.execute).toHaveBeenCalledWith({ farmId: 123 });

      component.control = {
        ...component.control,
        farm: {
          ...component.control.farm!,
          weather_data_status: 'completed',
          weather_data_progress: 100
        }
      };
      loadUseCase.execute.mockClear();
      vi.advanceTimersByTime(6000);
      expect(loadUseCase.execute).not.toHaveBeenCalled();
    } finally {
      vi.useRealTimers();
    }
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

  it('shows master context header and omits back button from detail-card__actions', () => {
    translate.setTranslation('ja', {
      farms: {
        index: { title: '農場一覧' },
        show: { location: '地域' },
        form: { region_blank: '未選択' }
      }
    });
    component.control = {
      loading: false,
      error: null,
      farm: { id: 123, name: 'テスト農場', region: null, latitude: 35.0, longitude: 139.0 },
      fields: [],
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    fixture.detectChanges();

    const backLink = fixture.nativeElement.querySelector(
      'a.master-context-header__back'
    ) as HTMLAnchorElement;
    expect(backLink?.getAttribute('href')).toBe('/farms');
    expect(backLink?.textContent?.trim()).toContain('農場一覧');
    expect(fixture.nativeElement.querySelector('[aria-current="page"]')?.textContent?.trim()).toBe(
      'テスト農場'
    );
    expect(
      fixture.nativeElement.querySelectorAll('.detail-card__actions a.btn-secondary')
    ).toHaveLength(0);
  });

  it('keeps list breadcrumb link while loading', () => {
    translate.setTranslation('ja', {
      farms: { index: { title: '農場一覧' } }
    });
    component.control = {
      loading: true,
      error: null,
      farm: null,
      fields: [],
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('a.master-context-header__back')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('[aria-current="page"]')).toBeNull();
  });

  it('keeps list breadcrumb link on error', () => {
    translate.setTranslation('ja', {
      farms: { index: { title: '農場一覧' } }
    });
    component.control = {
      loading: false,
      error: 'Not found',
      farm: null,
      fields: [],
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('a.master-context-header__back')).toBeTruthy();
  });
});