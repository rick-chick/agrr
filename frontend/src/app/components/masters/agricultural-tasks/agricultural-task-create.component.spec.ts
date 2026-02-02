import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, ActivatedRoute } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { of } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';

import { AgriculturalTaskCreateComponent } from './agricultural-task-create.component';
import { AgriculturalTaskCreatePresenter } from '../../../adapters/agricultural-tasks/agricultural-task-create.presenter';
import { CreateAgriculturalTaskUseCase } from '../../../usecase/agricultural-tasks/create-agricultural-task.usecase';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';
import { AuthService } from '../../../services/auth.service';

describe('AgriculturalTaskCreateComponent', () => {
  let component: AgriculturalTaskCreateComponent;
  let fixture: ComponentFixture<AgriculturalTaskCreateComponent>;
  let mockRouter: any;
  let mockActivatedRoute: any;
  let mockUseCase: any;
  let mockPresenter: any;
  let mockAuthService: any;

  beforeEach(async () => {
    mockRouter = {
      navigate: vi.fn(),
      routerState: { root: {} },
      createUrlTree: vi.fn(),
      serializeUrl: vi.fn(),
      events: of() // Add events observable
    };
    mockActivatedRoute = {}; // Empty mock for ActivatedRoute
    mockUseCase = { execute: vi.fn() };
    mockPresenter = { setView: vi.fn() };
    mockAuthService = { user: vi.fn(() => ({ admin: true, region: 'us' })) };

    await TestBed.configureTestingModule({
      imports: [
        AgriculturalTaskCreateComponent,
        RegionSelectComponent,
        TranslateModule.forRoot()
      ],
      // Do not provide component-level presenters/usecases here; override the component providers below
      providers: [
        { provide: Router, useValue: mockRouter },
        { provide: ActivatedRoute, useValue: mockActivatedRoute },
        { provide: AuthService, useValue: mockAuthService }
      ]
    });

    // Override component-level providers so injected instances inside the component are the test mocks
    TestBed.overrideComponent(AgriculturalTaskCreateComponent, {
      set: {
        providers: [
          { provide: CreateAgriculturalTaskUseCase, useValue: mockUseCase },
          { provide: AgriculturalTaskCreatePresenter, useValue: mockPresenter }
        ]
      }
    });

    await TestBed.compileComponents();

    fixture = TestBed.createComponent(AgriculturalTaskCreateComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should call useCase when createAgriculturalTask is called', () => {
    mockAuthService.user.mockReturnValue({ admin: true, region: 'us' });
    // Set component control without triggering template rendering
    component.control = {
      saving: false,
      error: null,
      formData: {
        name: 'New Task',
        description: 'New Description',
        time_per_sqm: 2.0,
        weather_dependency: 'low',
        required_tools: [],
        skill_level: 'beginner',
        region: 'us',
        task_type: 'automated'
      }
    };

    // Directly set _control to ensure it's not saving
    (component as any)._control = {
      saving: false,
      error: null,
      formData: {
        name: 'New Task',
        description: 'New Description',
        time_per_sqm: 2.0,
        weather_dependency: 'low',
        required_tools: [],
        skill_level: 'beginner',
        region: 'us',
        task_type: 'automated'
      }
    };

    component.createAgriculturalTask();

    expect(mockUseCase.execute).toHaveBeenCalledWith({
      name: 'New Task',
      description: 'New Description',
      time_per_sqm: 2.0,
      weather_dependency: 'low',
      required_tools: [],
      skill_level: 'beginner',
      region: 'us',
      task_type: 'automated',
      onSuccess: expect.any(Function)
    });
  });

  it('defaults region to current user region for non-admin users', () => {
    mockAuthService.user.mockReturnValue({ admin: false, region: 'jp' });
    component.control = {
      saving: false,
      error: null,
      formData: {
        name: 'New Task',
        description: 'New Description',
        time_per_sqm: 2.0,
        weather_dependency: 'low',
        required_tools: [],
        skill_level: 'beginner',
        region: null,
        task_type: 'automated'
      }
    };
    (component as any)._control = {
      saving: false,
      error: null,
      formData: {
        name: 'New Task',
        description: 'New Description',
        time_per_sqm: 2.0,
        weather_dependency: 'low',
        required_tools: [],
        skill_level: 'beginner',
        region: null,
        task_type: 'automated'
      }
    };

    component.createAgriculturalTask();

    expect(mockUseCase.execute).toHaveBeenCalledWith(
      expect.objectContaining({
        region: 'jp'
      })
    );
  });
});