import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { of } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';

import { AgriculturalTaskEditComponent } from './agricultural-task-edit.component';
import { AgriculturalTaskEditPresenter } from '../../../adapters/agricultural-tasks/agricultural-task-edit.presenter';
import { LoadAgriculturalTaskForEditUseCase } from '../../../usecase/agricultural-tasks/load-agricultural-task-for-edit.usecase';
import { UpdateAgriculturalTaskUseCase } from '../../../usecase/agricultural-tasks/update-agricultural-task.usecase';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';

describe('AgriculturalTaskEditComponent', () => {
  let component: AgriculturalTaskEditComponent;
  let fixture: ComponentFixture<AgriculturalTaskEditComponent>;
  let mockActivatedRoute: any;
  let mockLoadUseCase: any;
  let mockUpdateUseCase: any;

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

    await TestBed.configureTestingModule({
      imports: [AgriculturalTaskEditComponent, RegionSelectComponent, TranslateModule.forRoot()],
      providers: [
        AgriculturalTaskEditPresenter,
        { provide: ActivatedRoute, useValue: mockActivatedRoute },
        { provide: LoadAgriculturalTaskForEditUseCase, useValue: mockLoadUseCase },
        { provide: UpdateAgriculturalTaskUseCase, useValue: mockUpdateUseCase }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(AgriculturalTaskEditComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should have agriculturalTaskId set correctly', () => {
    expect(component['agriculturalTaskId']).toBe(1);
  });

  it('should call updateUseCase when updateAgriculturalTask is called', () => {
    // Set control first
    component.control = {
      loading: false,
      saving: false,
      error: null,
      formData: {
        name: 'Test Task',
        description: 'Test Description',
        time_per_sqm: 1.5,
        weather_dependency: 'medium',
        required_tools: [],
        skill_level: 'intermediate',
        region: 'jp',
        task_type: 'manual'
      }
    };

    // Directly set _control to ensure it's not saving
    (component as any)._control = {
      loading: false,
      saving: false,
      error: null,
      formData: {
        name: 'Test Task',
        description: 'Test Description',
        time_per_sqm: 1.5,
        weather_dependency: 'medium',
        required_tools: [],
        skill_level: 'intermediate',
        region: 'jp',
        task_type: 'manual'
      }
    };

    component.updateAgriculturalTask();

    expect(mockUpdateUseCase.execute).toHaveBeenCalledWith({
      agriculturalTaskId: 1,
      name: 'Test Task',
      description: 'Test Description',
      time_per_sqm: 1.5,
      weather_dependency: 'medium',
      required_tools: [],
      skill_level: 'intermediate',
      region: 'jp',
      task_type: 'manual',
      onSuccess: expect.any(Function)
    });
  });
});