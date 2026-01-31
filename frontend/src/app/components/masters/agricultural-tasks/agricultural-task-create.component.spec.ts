import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, ActivatedRoute } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { of } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';

import { AgriculturalTaskCreateComponent } from './agricultural-task-create.component';
import { AgriculturalTaskCreatePresenter } from '../../../adapters/agricultural-tasks/agricultural-task-create.presenter';
import { CreateAgriculturalTaskUseCase } from '../../../usecase/agricultural-tasks/create-agricultural-task.usecase';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';

describe('AgriculturalTaskCreateComponent', () => {
  let component: AgriculturalTaskCreateComponent;
  let fixture: ComponentFixture<AgriculturalTaskCreateComponent>;
  let mockRouter: any;
  let mockActivatedRoute: any;
  let mockUseCase: any;
  let mockPresenter: any;

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

    await TestBed.configureTestingModule({
      imports: [
        AgriculturalTaskCreateComponent,
        RegionSelectComponent,
        TranslateModule.forRoot()
      ],
      providers: [
        { provide: AgriculturalTaskCreatePresenter, useValue: mockPresenter },
        { provide: Router, useValue: mockRouter },
        { provide: ActivatedRoute, useValue: mockActivatedRoute },
        { provide: CreateAgriculturalTaskUseCase, useValue: mockUseCase }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(AgriculturalTaskCreateComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should call useCase when createAgriculturalTask is called', () => {
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
});