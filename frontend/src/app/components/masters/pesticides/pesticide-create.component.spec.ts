import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, ActivatedRoute } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, vi } from 'vitest';

import { PesticideCreateComponent } from './pesticide-create.component';
import { PesticideCreatePresenter } from '../../../adapters/pesticides/pesticide-create.presenter';
import { CreatePesticideUseCase } from '../../../usecase/pesticides/create-pesticide.usecase';
import { CROP_GATEWAY } from '../../../usecase/crops/crop-gateway';
import { PEST_GATEWAY } from '../../../usecase/pests/pest-gateway';
import { PESTICIDE_GATEWAY } from '../../../usecase/pesticides/pesticide-gateway';
import { AuthService } from '../../../services/auth.service';

describe('PesticideCreateComponent', () => {
  let component: PesticideCreateComponent;
  let fixture: ComponentFixture<PesticideCreateComponent>;
  let mockRouter: any;
  let mockActivatedRoute: any;
  let mockPresenter: any;
  let mockCreateUseCase: any;
  let mockCropGateway: any;
  let mockPestGateway: any;
  let mockAuth: any;

  beforeEach(async () => {
    mockRouter = {
      navigate: vi.fn(),
      events: { subscribe: vi.fn() }, // Router events observable
      routerState: {},
      url: '',
      createUrlTree: vi.fn(),
      serializeUrl: vi.fn()
    };

    mockActivatedRoute = {
      snapshot: {
        paramMap: {
          get: () => null
        }
      }
    };

    mockPresenter = {
      setView: vi.fn()
    };

    mockCreateUseCase = {
      execute: vi.fn()
    };

    mockCropGateway = {
      list: vi.fn()
    };

    mockPestGateway = {
      list: vi.fn()
    };

    mockAuth = {
      user: vi.fn(() => ({ admin: false, region: 'jp' }))
    };

    await TestBed.configureTestingModule({
      imports: [PesticideCreateComponent, TranslateModule.forRoot()],
      providers: [
        { provide: PesticideCreatePresenter, useValue: mockPresenter },
        { provide: Router, useValue: mockRouter },
        { provide: ActivatedRoute, useValue: mockActivatedRoute },
        { provide: CreatePesticideUseCase, useValue: mockCreateUseCase },
        { provide: AuthService, useValue: mockAuth },
        { provide: CROP_GATEWAY, useValue: mockCropGateway },
        { provide: PEST_GATEWAY, useValue: mockPestGateway },
        { provide: PESTICIDE_GATEWAY, useValue: {} }
      ]
    })
    .overrideComponent(PesticideCreateComponent, {
      set: {
        providers: [
          { provide: PesticideCreatePresenter, useValue: mockPresenter },
          { provide: Router, useValue: mockRouter },
          { provide: ActivatedRoute, useValue: mockActivatedRoute },
          { provide: CreatePesticideUseCase, useValue: mockCreateUseCase },
          { provide: AuthService, useValue: mockAuth },
          { provide: CROP_GATEWAY, useValue: mockCropGateway },
          { provide: PEST_GATEWAY, useValue: mockPestGateway },
          { provide: PESTICIDE_GATEWAY, useValue: {} }
        ]
      }
    })
    .compileComponents();

    fixture = TestBed.createComponent(PesticideCreateComponent);
    component = fixture.componentInstance;
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should implement View interface control getter/setter', () => {
    const testState = {
      saving: true,
      error: 'Test error',
      formData: {
        name: 'Test',
        active_ingredient: null,
        description: null,
        crop_id: 1,
        pest_id: 1,
        region: 'jp'
      }
    };

    component.control = testState;
    expect(component.control).toEqual(testState);
  });

  it('should have region field in formData', () => {
    expect(component.control.formData).toHaveProperty('region');
    expect(component.control.formData.region).toBeNull(); // Initially null
  });

  it('uses user region for non-admin submissions', () => {
    component.control = {
      saving: false,
      error: null,
      formData: {
        name: 'Test',
        active_ingredient: null,
        description: null,
        crop_id: 1,
        pest_id: 1,
        region: null
      }
    };

    component.createPesticide();
    expect(mockCreateUseCase.execute).toHaveBeenCalledWith(expect.objectContaining({ region: 'jp' }));
  });

  it('uses selected region for admin submissions', () => {
    mockAuth.user.mockReturnValue({ admin: true, region: 'jp' });
    component.control = {
      saving: false,
      error: null,
      formData: {
        name: 'Test',
        active_ingredient: null,
        description: null,
        crop_id: 1,
        pest_id: 1,
        region: 'us'
      }
    };

    component.createPesticide();
    expect(mockCreateUseCase.execute).toHaveBeenCalledWith(expect.objectContaining({ region: 'us' }));
  });
});