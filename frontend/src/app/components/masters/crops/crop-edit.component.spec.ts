import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, vi } from 'vitest';

import { CropEditComponent } from './crop-edit.component';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';
import { AuthService } from '../../../services/auth.service';
import { CropEditPresenter } from '../../../usecase/crops/crop-edit.providers';
import { LoadCropForEditUseCase } from '../../../usecase/crops/load-crop-for-edit.usecase';
import { UpdateCropUseCase } from '../../../usecase/crops/update-crop.usecase';

const initialFormData = {
  name: '',
  variety: null,
  area_per_unit: null,
  revenue_per_area: null,
  region: null,
  groups: [],
  groupsDisplay: '',
  is_reference: false
};

describe('CropEditComponent', () => {
  let component: CropEditComponent;
  let fixture: ComponentFixture<CropEditComponent>;
  let mockActivatedRoute: { snapshot: { paramMap: { get: () => string } } };
  let mockLoadUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockUpdateUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockAuthService: { user: ReturnType<typeof vi.fn> };

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
    mockAuthService = {
      user: vi.fn(() => ({ admin: true, region: 'us' }))
    };

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
        { provide: AuthService, useValue: mockAuthService }
      ]
    }).compileComponents();

    TestBed.overrideProvider(LoadCropForEditUseCase, { useValue: mockLoadUseCase });
    TestBed.overrideProvider(UpdateCropUseCase, { useValue: mockUpdateUseCase });

    fixture = TestBed.createComponent(CropEditComponent);
    component = fixture.componentInstance;

    const translateService = TestBed.inject(TranslateService);
    translateService.setTranslation('ja', {
      crops: {
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
    expect(component['cropId']).toBe(1);
    fixture.detectChanges();
    expect(mockLoadUseCase.execute).toHaveBeenCalledWith({ cropId: 1 });
  });

  it('should use current user region for non-admin updates', () => {
    mockAuthService.user.mockReturnValue({ admin: false, region: 'jp' });
    component.control = {
      loading: false,
      saving: false,
      error: null,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
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
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
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
});
