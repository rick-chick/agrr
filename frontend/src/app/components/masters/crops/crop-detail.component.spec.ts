import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import en from '../../../../assets/i18n/en.json';
import { CropDetailComponent } from './crop-detail.component';
import type { CropDetailViewState } from './crop-detail.view';
import { CropDetailPresenter } from '../../../usecase/crops/crop-detail.providers';
import { LoadCropDetailUseCase } from '../../../usecase/crops/load-crop-detail.usecase';
import { DeleteCropUseCase } from '../../../usecase/crops/delete-crop.usecase';
import { LoadCropTaskTemplatesUseCase } from '../../../usecase/crops/load-crop-task-templates.usecase';
import { CreateCropTaskTemplateUseCase } from '../../../usecase/crops/create-crop-task-template.usecase';
import { DeleteCropTaskTemplateUseCase } from '../../../usecase/crops/delete-crop-task-template.usecase';
import { LoadAgriculturalTaskListUseCase } from '../../../usecase/agricultural-tasks/load-agricultural-task-list.usecase';
import { LoadCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/load-crop-task-schedule-blueprints.usecase';
import { CreateCropTaskScheduleBlueprintUseCase } from '../../../usecase/crops/create-crop-task-schedule-blueprint.usecase';
import { RegenerateCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/regenerate-crop-task-schedule-blueprints.usecase';
import { UpdateCropTaskScheduleBlueprintUseCase } from '../../../usecase/crops/update-crop-task-schedule-blueprint.usecase';
import { DeleteCropTaskScheduleBlueprintUseCase } from '../../../usecase/crops/delete-crop-task-schedule-blueprint.usecase';

const loadedState: CropDetailViewState = {
  loading: false,
  error: null,
  crop: {
    id: 3,
    name: 'Tomato',
    variety: null,
    area_per_unit: null,
    revenue_per_area: null,
    groups: [],
    region: 'jp',
    is_reference: false,
    crop_stages: [],
    created_at: null,
    updated_at: null
  },
  pendingUndoToast: null,
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  taskTemplatesLoading: false,
  taskTemplates: [
    {
      id: 10,
      crop_id: 3,
      agricultural_task_id: 5,
      name: 'Weeding',
      required_tools: [],
      agricultural_task: { id: 5, name: 'Weeding', is_reference: false }
    }
  ],
  agriculturalTasksLoading: false,
  agriculturalTasks: [
    { id: 5, name: 'Weeding', required_tools: [], is_reference: false },
    { id: 6, name: 'Fertilizing', required_tools: [], is_reference: false }
  ],
  unassociatedAgriculturalTasks: [
    { id: 6, name: 'Fertilizing', required_tools: [], is_reference: false }
  ],
  selectedAgriculturalTaskId: null,
  taskTemplateCreating: false,
  blueprintsLoading: false,
  blueprints: [
    {
      id: 20,
      crop_id: 3,
      agricultural_task_id: 5,
      source_agricultural_task_id: null,
      stage_order: 1,
      stage_name: 'Vegetative',
      gdd_trigger: 120,
      gdd_tolerance: null,
      task_type: 'field_work',
      source: 'agrr',
      priority: 1,
      amount: null,
      amount_unit: null,
      description: 'Early weeding',
      weather_dependency: null,
      time_per_sqm: null,
      name: 'Weeding',
      agricultural_task: { id: 5, name: 'Weeding' }
    }
  ],
  blueprintsRegenerating: false,
  blueprintGddSavingId: null,
  blueprintGddDrafts: { 20: 120 },
  blueprintRegenerateError: null,
  selectedBlueprintStageOrder: null,
  selectedBlueprintAgriculturalTaskId: null,
  blueprintCreateGddTrigger: null,
  blueprintCreating: false
};

const cropWithReadyStages = {
  ...loadedState.crop!,
  crop_stages: [
    {
      id: 1,
      crop_id: 3,
      name: 'Vegetative',
      order: 1,
      temperature_requirement: {
        id: 1,
        crop_stage_id: 1,
        base_temperature: 10,
        optimal_min: 15,
        optimal_max: 25
      },
      thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 500 }
    }
  ]
};

const readyState: CropDetailViewState = {
  ...loadedState,
  crop: cropWithReadyStages
};

describe('CropDetailComponent', () => {
  let fixture: ComponentFixture<CropDetailComponent>;
  let component: CropDetailComponent;
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let loadTaskTemplatesUseCase: { execute: ReturnType<typeof vi.fn> };
  let loadAgriculturalTasksUseCase: { execute: ReturnType<typeof vi.fn> };
  let loadBlueprintsUseCase: { execute: ReturnType<typeof vi.fn> };
  let createTaskTemplateUseCase: { execute: ReturnType<typeof vi.fn> };
  let deleteTaskTemplateUseCase: { execute: ReturnType<typeof vi.fn> };
  let createBlueprintUseCase: { execute: ReturnType<typeof vi.fn> };
  let regenerateBlueprintsUseCase: { execute: ReturnType<typeof vi.fn> };
  let updateBlueprintUseCase: { execute: ReturnType<typeof vi.fn> };
  let deleteBlueprintUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: { setView: ReturnType<typeof vi.fn> };
  let mockActivatedRoute: {
    snapshot: {
      paramMap: { get: ReturnType<typeof vi.fn> };
      queryParamMap: { get: ReturnType<typeof vi.fn> };
      fragment?: string | null;
    };
  };

  beforeEach(async () => {
    loadUseCase = { execute: vi.fn() };
    loadTaskTemplatesUseCase = { execute: vi.fn() };
    loadAgriculturalTasksUseCase = { execute: vi.fn() };
    loadBlueprintsUseCase = { execute: vi.fn() };
    createTaskTemplateUseCase = { execute: vi.fn() };
    deleteTaskTemplateUseCase = { execute: vi.fn() };
    createBlueprintUseCase = { execute: vi.fn() };
    regenerateBlueprintsUseCase = { execute: vi.fn() };
    updateBlueprintUseCase = { execute: vi.fn() };
    deleteBlueprintUseCase = { execute: vi.fn() };
    mockPresenter = { setView: vi.fn() };
    mockActivatedRoute = {
      snapshot: {
        paramMap: { get: vi.fn(() => '3') },
        queryParamMap: { get: vi.fn(() => null) },
        fragment: null
      }
    };

    TestBed.overrideComponent(CropDetailComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadCropDetailUseCase, useValue: loadUseCase },
          { provide: DeleteCropUseCase, useValue: { execute: vi.fn() } },
          { provide: LoadCropTaskTemplatesUseCase, useValue: loadTaskTemplatesUseCase },
          { provide: CreateCropTaskTemplateUseCase, useValue: createTaskTemplateUseCase },
          { provide: DeleteCropTaskTemplateUseCase, useValue: deleteTaskTemplateUseCase },
          { provide: LoadAgriculturalTaskListUseCase, useValue: loadAgriculturalTasksUseCase },
          { provide: LoadCropTaskScheduleBlueprintsUseCase, useValue: loadBlueprintsUseCase },
          { provide: RegenerateCropTaskScheduleBlueprintsUseCase, useValue: regenerateBlueprintsUseCase },
          { provide: CreateCropTaskScheduleBlueprintUseCase, useValue: createBlueprintUseCase },
          { provide: UpdateCropTaskScheduleBlueprintUseCase, useValue: updateBlueprintUseCase },
          { provide: DeleteCropTaskScheduleBlueprintUseCase, useValue: deleteBlueprintUseCase },
          { provide: CropDetailPresenter, useValue: mockPresenter },
          { provide: ChangeDetectorRef, useValue: { markForCheck: vi.fn() } },
          {
            provide: ActivatedRoute,
            useValue: mockActivatedRoute
          }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [CropDetailComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(CropDetailComponent);
    component = fixture.componentInstance;
  });

  it('loads crop detail and task sections on init', () => {
    component.ngOnInit();
    expect(mockPresenter.setView).toHaveBeenCalledWith(component);
    expect(loadUseCase.execute).toHaveBeenCalledWith({ cropId: 3 });
    expect(loadTaskTemplatesUseCase.execute).toHaveBeenCalledWith({ cropId: 3 });
    expect(loadAgriculturalTasksUseCase.execute).toHaveBeenCalled();
    expect(loadBlueprintsUseCase.execute).toHaveBeenCalledWith({ cropId: 3 });
  });

  it('creates task template when agricultural task is selected', () => {
    component.control = { ...loadedState, selectedAgriculturalTaskId: 6 };
    component.createTaskTemplate();
    expect(createTaskTemplateUseCase.execute).toHaveBeenCalledWith({
      cropId: 3,
      agriculturalTaskId: 6
    });
  });

  it('regenerates blueprints after confirm when readiness is satisfied', () => {
    vi.spyOn(window, 'confirm').mockReturnValue(true);
    component.control = readyState;
    component.regenerateBlueprints();
    expect(regenerateBlueprintsUseCase.execute).toHaveBeenCalledWith({ cropId: 3 });
  });

  it('shows return-to-plan link when fromPlan query param is set', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            return_to_plan: 'Return to plan',
            from_plan_wizard_title: 'Registration for this plan',
            from_plan_wizard_lead: 'Complete STEP 1 then STEP 2.'
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');
    mockActivatedRoute.snapshot.queryParamMap.get.mockImplementation((key: string) =>
      key === 'fromPlan' ? '7' : null
    );

    fixture.detectChanges();
    component.control = loadedState;
    fixture.detectChanges();
    await fixture.whenStable();

    const link = fixture.nativeElement.querySelector(
      'a[href*="/plans/7/work"]'
    ) as HTMLAnchorElement | null;
    expect(link).toBeTruthy();
    expect(link?.textContent).toContain('Return to plan');
    expect(fixture.nativeElement.querySelector('.crop-detail__plan-wizard-banner')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Registration for this plan');
  });

  it('disables regenerate button and shows readiness checklist when stages are incomplete', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            task_schedule_blueprints_title: 'Task Plan',
            generate_task_schedule_blueprints_button: 'Regenerate Task Plan (AI)',
            blueprint_readiness: {
              title: 'Required before AI generation',
              templates_missing: 'No task templates registered',
              templates_action: 'Register task templates',
              stages_missing: 'Growth stages are missing base temperature or required GDD',
              stages_action: 'Edit crop to configure stage requirements'
            }
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = loadedState;
    fixture.detectChanges();
    await fixture.whenStable();

    const button = fixture.nativeElement.querySelector(
      '.crop-detail__blueprint-ai-import .btn-secondary'
    ) as HTMLButtonElement;
    expect(button.disabled).toBe(true);
    expect(fixture.nativeElement.querySelector('.blueprint-readiness')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Growth stages are missing');
    expect(fixture.nativeElement.querySelector('a[href="#task-templates-heading"]')).toBeFalsy();
    expect(fixture.nativeElement.querySelector('a[href="/crops/3/edit"]')).toBeTruthy();
  });

  it('enables regenerate button when templates and stage requirements are ready', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            task_schedule_blueprints_title: 'Task Plan',
            generate_task_schedule_blueprints_button: 'Regenerate Task Plan (AI)'
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = readyState;
    fixture.detectChanges();
    await fixture.whenStable();

    const button = fixture.nativeElement.querySelector(
      '.crop-detail__blueprint-ai-import .btn-secondary'
    ) as HTMLButtonElement;
    expect(button.disabled).toBe(false);
    expect(fixture.nativeElement.querySelector('.blueprint-readiness')).toBeFalsy();
  });

  it('creates blueprint manually when stage, task, and gdd are selected', () => {
    component.control = {
      ...readyState,
      selectedBlueprintStageOrder: 1,
      selectedBlueprintAgriculturalTaskId: 5,
      blueprintCreateGddTrigger: 120
    };
    component.createBlueprint();
    expect(createBlueprintUseCase.execute).toHaveBeenCalledWith({
      cropId: 3,
      agriculturalTaskId: 5,
      stageOrder: 1,
      stageName: 'Vegetative',
      gddTrigger: 120
    });
  });

  it('shows step badges and always-visible template section description', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            agricultural_tasks_title: 'Task Templates',
            agricultural_tasks_step_label: 'STEP 1',
            agricultural_tasks_description:
              'Register tasks for this crop. The task plan below is generated from these templates.',
            task_schedule_blueprints_title: 'Task Plan',
            task_schedule_blueprints_step_label: 'STEP 2',
            generate_task_schedule_blueprints_button: 'Regenerate Task Plan (AI)',
            task_schedule_blueprints_description_html: 'Review AI-suggested task plans.',
            task_schedule_blueprints_description_empty_html: 'Press the button above to generate.'
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = readyState;
    fixture.detectChanges();
    await fixture.whenStable();

    const templateSection = fixture.nativeElement.querySelector(
      '#task-templates-heading'
    )?.closest('section');
    const blueprintSection = fixture.nativeElement.querySelector(
      '#blueprints-heading'
    )?.closest('section');

    expect(templateSection?.querySelector('.crop-detail__step-badge')?.textContent).toContain('STEP 1');
    expect(blueprintSection?.querySelector('.crop-detail__step-badge')?.textContent).toContain('STEP 2');
    expect(templateSection?.textContent).toContain(
      'Register tasks for this crop. The task plan below is generated from these templates.'
    );
  });

  it('renders manual blueprint add form when readiness is satisfied', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            manual_blueprint_add: {
              title: 'Add task plan manually',
              description: 'Register stage, task, and GDD.',
              stage_label: 'Growth stage',
              task_label: 'Task',
              gdd_label: 'GDD',
              submit: 'Add task plan',
              ai_hint: 'AI replaces all plans.'
            },
            generate_task_schedule_blueprints_button: 'Import AI suggestions',
            gdd_unit: '°C·day'
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = readyState;
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.querySelector('.crop-detail__blueprint-add-form')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('#blueprint-stage-picker')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('#blueprint-task-picker')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('#blueprint-gdd-input')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Add task plan manually');
  });

  it('renders blueprint cards with shared card-list layout, GDD input, and delete label', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        common: { delete: 'Delete' },
        crops: { show: { delete_blueprint: 'Delete task plan' } }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = {
      ...readyState,
      blueprints: [
        readyState.blueprints[0],
        { ...readyState.blueprints[0], id: 21, stage_order: 2, stage_name: 'Flowering' }
      ],
      blueprintGddDrafts: { 20: 120, 21: 80 }
    };
    fixture.detectChanges();
    await fixture.whenStable();

    const blueprintList = fixture.nativeElement.querySelector('.crop-detail__blueprint-list');
    const templateList = fixture.nativeElement.querySelector(
      '#task-templates-heading'
    )?.closest('section')?.querySelector('.card-list');
    const card = fixture.nativeElement.querySelector('.blueprint-card');
    const gddField = card?.querySelector('.blueprint-card__gdd');
    const deleteButton = card?.querySelector('.item-card__actions .crop-detail__card-remove');

    expect(blueprintList?.classList.contains('card-list')).toBe(true);
    expect(templateList).toBeTruthy();
    expect(fixture.nativeElement.querySelectorAll('.blueprint-card').length).toBe(2);
    expect(card?.querySelector('.item-card__body')).toBeTruthy();
    expect(card?.querySelector('.item-card__actions')).toBeTruthy();
    expect(card?.querySelector('.item-card__body .blueprint-card__gdd')).toBeTruthy();
    expect(gddField?.querySelector('.crop-detail__template-add-input-wrap')).toBeTruthy();
    expect(gddField?.querySelector('#gdd-20.crop-detail__template-add-input')).toBeTruthy();
    expect(gddField?.querySelector('.crop-detail__template-add-input-unit')).toBeTruthy();
    expect(deleteButton?.textContent?.trim()).toBe('Delete');
    expect(deleteButton?.getAttribute('aria-label')).toBe('Delete task plan');
  });

  it('does not show task type or missing-task placeholder on blueprint cards', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = {
      ...readyState,
      blueprints: [
        {
          ...readyState.blueprints[0],
          agricultural_task: undefined,
          name: undefined,
          description: 'Plowing only'
        }
      ],
      blueprintGddDrafts: { 20: 120 }
    };
    fixture.detectChanges();
    await fixture.whenStable();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('Plowing only');
    expect(text).not.toContain('Field work');
    expect(text).not.toContain('Unlinked task');
  });

  it('renders task templates and blueprint sections', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = readyState;
    fixture.detectChanges();
    await fixture.whenStable();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('Task Templates');
    expect(text).toContain('Weeding');
    expect(text).toContain('Task Plan');
    expect(text).toContain('Early weeding');
    expect(fixture.nativeElement.querySelector('#task-templates-heading')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('#blueprints-heading')).toBeTruthy();
  });

  it('shows blueprint task name from name field when agricultural_task is absent', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = {
      ...loadedState,
      blueprints: [
        {
          ...loadedState.blueprints[0],
          name: 'Soil preparation',
          agricultural_task: undefined
        }
      ]
    };
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.textContent).toContain('Soil preparation');
    expect(fixture.nativeElement.textContent).not.toContain('Unlinked task');
  });

  it('hides empty blueprint message when regenerate failed with inline error', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            task_schedule_blueprints_title: 'Task Plan',
            generate_task_schedule_blueprints_button: 'Regenerate Task Plan (AI)',
            no_task_schedule_blueprints: 'No task plans have been defined yet.',
            blueprint_errors: {
              generic: 'Failed to generate task plans.'
            }
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = {
      ...readyState,
      blueprints: [],
      blueprintRegenerateError: 'crops.show.blueprint_errors.generic'
    };
    fixture.detectChanges();
    await fixture.whenStable();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('Failed to generate task plans.');
    expect(text).not.toContain('No task plans have been defined yet.');
  });

  it('shows empty blueprint intro instead of generated-plan description when list is empty', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            task_schedule_blueprints_title: 'Task Plan',
            generate_task_schedule_blueprints_button: 'Regenerate Task Plan (AI)',
            task_schedule_blueprints_description_html: 'These tasks were suggested by the AI.',
            task_schedule_blueprints_description_empty_html:
              'Use the form below to register task plans.',
            no_task_schedule_blueprints: 'No task plans have been defined yet.'
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = { ...readyState, blueprints: [] };
    fixture.detectChanges();
    await fixture.whenStable();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('Use the form below to register task plans.');
    expect(text).not.toContain('These tasks were suggested by the AI.');
    expect(text).toContain('No task plans have been defined yet.');
  });

  it('shows generated-plan description when blueprints exist', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            task_schedule_blueprints_title: 'Task Plan',
            generate_task_schedule_blueprints_button: 'Regenerate Task Plan (AI)',
            task_schedule_blueprints_description_html: 'These tasks were suggested by the AI.',
            task_schedule_blueprints_description_empty_html:
              'Press Regenerate Task Plan (AI) above to generate a draft.'
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = readyState;
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.textContent).toContain('These tasks were suggested by the AI.');
  });

  it('uses subsection layout for template add area and subdued card remove buttons', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = loadedState;
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.querySelector('.crop-detail__template-add')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.crop-detail__template-add.form-card')).toBeFalsy();
    expect(
      fixture.nativeElement.querySelector('.card-list .crop-detail__card-remove')
    ).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.card-list .btn-danger')).toBeFalsy();
  });

  it('renders inline picker form when unassociated agricultural tasks exist', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = loadedState;
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.querySelector('.crop-detail__template-add-form')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('#agricultural-task-picker')).toBeTruthy();
    expect(
      fixture.nativeElement.querySelector('.crop-detail__template-add-actions .btn-primary')
    ).toBeTruthy();
  });

  it('explains all work-master tasks are already templated when picker is empty but templates exist', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          agricultural_tasks: {
            new: {
              associate_existing_task: 'Create Template from Existing Task',
              no_unassociated_tasks_all_templated:
                'The list above shows templates already registered for this crop.',
              go_to_create: 'Go to Task Creation'
            }
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = { ...loadedState, unassociatedAgriculturalTasks: [] };
    fixture.detectChanges();
    await fixture.whenStable();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('The list above shows templates already registered for this crop.');
    expect(
      fixture.nativeElement.querySelector('.crop-detail__template-add-empty .btn-secondary')
    ).toBeTruthy();
  });

  it('shows retry action for retriable regenerate errors when readiness is satisfied', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            task_schedule_blueprints_title: 'Task Plan',
            generate_task_schedule_blueprints_button: 'Regenerate Task Plan (AI)',
            blueprint_errors: {
              generic: 'Failed to generate task plans.',
              retry_action: 'Try again'
            }
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = {
      ...readyState,
      blueprints: [],
      blueprintRegenerateError: 'crops.show.blueprint_errors.generic'
    };
    fixture.detectChanges();
    await fixture.whenStable();

    const retryButton = fixture.nativeElement.querySelector(
      '.blueprint-regenerate-error .btn-secondary'
    ) as HTMLButtonElement;
    expect(retryButton).toBeTruthy();
    expect(retryButton.textContent).toContain('Try again');
  });

  it('formats created_at and updated_at using the active app language', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('ja', { crops: { show: { created_at: '作成日', updated_at: '更新日' } } }, true);
    translate.setDefaultLang('ja');
    translate.use('ja');

    fixture.detectChanges();
    component.control = {
      ...loadedState,
      crop: {
        ...loadedState.crop!,
        created_at: '2026-06-25 09:03:01',
        updated_at: '2026-06-25 10:15:00'
      }
    };
    fixture.detectChanges();
    await fixture.whenStable();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('2026年6月25日 9:03');
    expect(text).toContain('2026年6月25日 10:15');
    expect(text).not.toContain('Jun');
    expect(text).not.toContain('AM');
  });

  it('scrolls to the fragment target after section loading completes', async () => {
    mockActivatedRoute.snapshot.fragment = 'blueprints-heading';

    const scrollIntoView = vi.fn();
    const target = { scrollIntoView } as unknown as HTMLElement;
    const getElementById = vi.spyOn(document, 'getElementById').mockReturnValue(target);

    component.control = { ...readyState, blueprintsLoading: false, taskTemplatesLoading: false };
    fixture.detectChanges();
    await Promise.resolve();
    await fixture.whenStable();

    expect(getElementById).toHaveBeenCalledWith('blueprints-heading');
    expect(scrollIntoView).toHaveBeenCalledWith({ behavior: 'smooth', block: 'start' });

    getElementById.mockRestore();
    mockActivatedRoute.snapshot.fragment = null;
  });
});
