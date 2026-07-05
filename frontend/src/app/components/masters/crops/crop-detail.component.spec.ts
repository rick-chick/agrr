import { CdkDragDrop } from '@angular/cdk/drag-drop';
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
import { LoadAgriculturalTaskListUseCase } from '../../../usecase/agricultural-tasks/load-agricultural-task-list.usecase';
import { LoadCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/load-crop-task-schedule-blueprints.usecase';
import { CreateCropTaskScheduleBlueprintUseCase } from '../../../usecase/crops/create-crop-task-schedule-blueprint.usecase';
import { RegenerateCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/regenerate-crop-task-schedule-blueprints.usecase';
import { UpdateCropTaskScheduleBlueprintUseCase } from '../../../usecase/crops/update-crop-task-schedule-blueprint.usecase';
import { DeleteCropTaskScheduleBlueprintUseCase } from '../../../usecase/crops/delete-crop-task-schedule-blueprint.usecase';
import {
  defaultBlueprintReadiness,
  withCropDetailDisplayState
} from '../../../adapters/crops/crop-detail-presenter.helpers';
import type { CropTaskScheduleBlueprint } from '../../../domain/crops/crop-task-schedule-blueprint';

const loadedState: CropDetailViewState = withCropDetailDisplayState({
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
  fromPlanId: null,
  agriculturalTasksLoading: false,
  agriculturalTasks: [
    { id: 5, name: 'Weeding', required_tools: [], is_reference: false },
    { id: 6, name: 'Fertilizing', required_tools: [], is_reference: false }
  ],
  unassociatedAgriculturalTasks: [
    { id: 6, name: 'Fertilizing', required_tools: [], is_reference: false }
  ],
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
  blueprintSavingId: null,
  blueprintGddDrafts: { 20: 120 },
  blueprintStageLanes: [],
  blueprintRegenerateError: null,
  selectedBlueprintStageOrder: null,
  selectedBlueprintAgriculturalTaskId: null,
  blueprintCreateGddTrigger: null,
  blueprintCreating: false,
  blueprintReadiness: defaultBlueprintReadiness(),
  canRegenerateBlueprints: false,
  canCreateBlueprint: false,
  blueprintStageNameForCreate: null,
  showBlueprintReadinessChecklist: false,
  blueprintSectionDescriptionKey: 'crops.show.task_schedule_blueprints_description_empty_html',
  showBlueprintEmptyState: true,
  showBlueprintRegenerateRetry: false
});

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
    },
    {
      id: 2,
      crop_id: 3,
      name: 'Flowering',
      order: 2,
      temperature_requirement: {
        id: 2,
        crop_stage_id: 2,
        base_temperature: 10,
        optimal_min: 15,
        optimal_max: 25
      },
      thermal_requirement: { id: 2, crop_stage_id: 2, required_gdd: 800 }
    }
  ]
};

const readyState: CropDetailViewState = withCropDetailDisplayState({
  ...loadedState,
  crop: cropWithReadyStages
});

describe('CropDetailComponent', () => {
  let fixture: ComponentFixture<CropDetailComponent>;
  let component: CropDetailComponent;
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let loadAgriculturalTasksUseCase: { execute: ReturnType<typeof vi.fn> };
  let loadBlueprintsUseCase: { execute: ReturnType<typeof vi.fn> };
  let createBlueprintUseCase: { execute: ReturnType<typeof vi.fn> };
  let regenerateBlueprintsUseCase: { execute: ReturnType<typeof vi.fn> };
  let updateBlueprintUseCase: { execute: ReturnType<typeof vi.fn>; executeDrop: ReturnType<typeof vi.fn> };
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
    loadAgriculturalTasksUseCase = { execute: vi.fn() };
    loadBlueprintsUseCase = { execute: vi.fn() };
    createBlueprintUseCase = { execute: vi.fn() };
    regenerateBlueprintsUseCase = { execute: vi.fn() };
    updateBlueprintUseCase = { execute: vi.fn(), executeDrop: vi.fn() };
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
    expect(loadAgriculturalTasksUseCase.execute).toHaveBeenCalled();
    expect(loadBlueprintsUseCase.execute).toHaveBeenCalledWith({ cropId: 3 });
  });

  it('shows error message when control has error and no crop', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          errors: {
            invalid_id: 'Invalid crop ID'
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = {
      ...loadedState,
      loading: false,
      error: 'Invalid crop ID',
      crop: null,
      agriculturalTasksLoading: false,
      blueprintsLoading: false
    };
    fixture.detectChanges();
    await fixture.whenStable();

    const errorEl = fixture.nativeElement.querySelector('.master-error');
    expect(errorEl).toBeTruthy();
    expect(errorEl?.textContent).toContain('Invalid crop ID');
    expect(fixture.nativeElement.querySelector('.detail-card')).toBeFalsy();
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
            from_plan_wizard_lead: 'Register task plans using the form below.'
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
    component.control = { ...loadedState, fromPlanId: 7 };
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
              blueprints_missing: 'No task plans registered yet',
              blueprints_action: 'Register task plans',
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
    expect(fixture.nativeElement.querySelector('a[href="#blueprints-heading"]')).toBeFalsy();
    expect(fixture.nativeElement.querySelector('a[href="/crops/3/edit"]')).toBeTruthy();
  });

  it('enables regenerate button when blueprints and stage requirements are ready', async () => {
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

  it('enables create blueprint button when task is selected via onBlueprintTaskChange', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = readyState;
    fixture.detectChanges();
    await fixture.whenStable();

    const button = fixture.nativeElement.querySelector(
      '.crop-detail__template-add-actions .btn-primary'
    ) as HTMLButtonElement;
    expect(button.disabled).toBe(true);

    component.onBlueprintTaskChange(6);
    fixture.detectChanges();

    expect(component.control.canCreateBlueprint).toBe(true);
    expect(button.disabled).toBe(false);
  });

  it('creates blueprint with task only when stage and gdd are omitted', () => {
    component.control = {
      ...loadedState,
      selectedBlueprintAgriculturalTaskId: 6,
      canCreateBlueprint: true
    };
    component.createBlueprint();
    expect(createBlueprintUseCase.execute).toHaveBeenCalledWith({
      cropId: 3,
      agriculturalTaskId: 6,
      stageOrder: null,
      stageName: null,
      gddTrigger: null
    });
  });

  it('creates blueprint with stage and gdd when provided', () => {
    component.control = withCropDetailDisplayState({
      ...readyState,
      selectedBlueprintStageOrder: 1,
      selectedBlueprintAgriculturalTaskId: 6,
      blueprintCreateGddTrigger: 120
    });
    component.createBlueprint();
    expect(createBlueprintUseCase.execute).toHaveBeenCalledWith({
      cropId: 3,
      agriculturalTaskId: 6,
      stageOrder: 1,
      stageName: 'Vegetative',
      gddTrigger: 120
    });
  });

  it('renders unified task plan section without separate template section', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            task_schedule_blueprints_title: 'Task Plan',
            task_schedule_blueprints_description_html: 'Review AI-suggested task plans.',
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

    expect(fixture.nativeElement.querySelector('#blueprints-heading')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('#task-templates-heading')).toBeFalsy();
    expect(fixture.nativeElement.querySelector('.crop-detail__step-badge')).toBeFalsy();
    expect(fixture.nativeElement.textContent).toContain('Task Plan');
  });

  it('renders manual blueprint add form with master task picker', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            manual_blueprint_add: {
              title: 'Add task plan manually',
              description: 'Select a task from the master list.',
              stage_label: 'Growth stage',
              task_label: 'Task',
              gdd_label: 'GDD',
              optional: '(optional)',
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
    expect(fixture.nativeElement.textContent).toContain('(optional)');
  });

  it('renders blueprint cards in stage lanes sorted by GDD with delete label', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        common: { delete: 'Delete' },
        crops: {
          show: {
            delete_blueprint: 'Delete task plan',
            blueprint_stage_lane: {
              unassigned: 'No stage assigned',
              board_label: 'Task plans grouped by growth stage'
            }
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = withCropDetailDisplayState({
      ...readyState,
      blueprints: [
        readyState.blueprints[0],
        {
          ...readyState.blueprints[0],
          id: 21,
          stage_order: 2,
          stage_name: 'Flowering',
          gdd_trigger: 80
        },
        {
          ...readyState.blueprints[0],
          id: 22,
          stage_order: null,
          stage_name: null,
          gdd_trigger: null
        }
      ],
      blueprintGddDrafts: { 20: 120, 21: 80, 22: null }
    });
    fixture.detectChanges();
    await fixture.whenStable();

    const board = fixture.nativeElement.querySelector('.blueprint-stage-board');
    const card = fixture.nativeElement.querySelector('.blueprint-card');
    const gddInput = fixture.nativeElement.querySelector('#gdd-20.crop-detail__template-add-input');
    const deleteButton = card?.querySelector('.blueprint-card__header .crop-detail__card-remove');

    expect(board).toBeTruthy();
    expect(fixture.nativeElement.querySelectorAll('.blueprint-stage-lane').length).toBe(3);
    expect(fixture.nativeElement.textContent).toContain('No stage assigned');
    expect(fixture.nativeElement.querySelectorAll('.blueprint-card').length).toBe(3);
    expect(fixture.nativeElement.querySelector('#stage-20')).toBeFalsy();
    expect(card?.querySelector('.blueprint-card__header')).toBeTruthy();
    expect(gddInput).toBeTruthy();
    expect(deleteButton?.textContent?.trim()).toBe('Delete');
    expect(deleteButton?.getAttribute('aria-label')).toBe('Delete task plan');
  });

  it('shows GDD input for blueprints without gdd_trigger so users can set it later', async () => {
    fixture.detectChanges();
    component.control = withCropDetailDisplayState({
      ...readyState,
      blueprints: [
        {
          ...readyState.blueprints[0],
          id: 22,
          stage_order: null,
          stage_name: null,
          gdd_trigger: null,
          name: 'Weeding'
        }
      ],
      blueprintGddDrafts: {}
    });
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.querySelector('#gdd-22.crop-detail__template-add-input')).toBeTruthy();
  });

  it('delegates blueprint drop to update use case with crop context', () => {
    fixture.detectChanges();
    component.control = readyState;
    fixture.detectChanges();

    const blueprint = readyState.blueprints[0];
    component.onBlueprintDropped(
      {
        previousContainer: { data: readyState.blueprintStageLanes[1].blueprints },
        container: { data: readyState.blueprintStageLanes[0].blueprints },
        previousIndex: 0,
        currentIndex: 0,
        item: { data: blueprint }
      } as CdkDragDrop<CropTaskScheduleBlueprint[]>,
      null
    );

    expect(updateBlueprintUseCase.executeDrop).toHaveBeenCalledWith({
      cropId: 3,
      dragged: blueprint,
      targetStageOrder: null,
      laneBlueprints: readyState.blueprintStageLanes[0].blueprints,
      dropIndex: 0,
      cropStages: [
        { order: 1, name: 'Vegetative' },
        { order: 2, name: 'Flowering' }
      ]
    });
    expect(updateBlueprintUseCase.execute).not.toHaveBeenCalled();
  });

  it('does not show task type or missing-task placeholder on blueprint cards', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = withCropDetailDisplayState({
      ...readyState,
      blueprints: [
        {
          ...readyState.blueprints[0],
          agricultural_task: undefined,
          name: 'Plowing only',
          description: 'Plowing only'
        }
      ],
      blueprintGddDrafts: { 20: 120 }
    });
    fixture.detectChanges();
    await fixture.whenStable();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('Plowing only');
    expect(text).not.toContain('Field work');
    expect(text).not.toContain('Unlinked task');
  });

  it('renders task plan section with blueprint list', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = readyState;
    fixture.detectChanges();
    await fixture.whenStable();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('Task Plan');
    expect(text).toContain('Weeding');
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
    component.control = withCropDetailDisplayState({ ...readyState, blueprints: [] });
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

  it('renders inline picker form when unassociated agricultural tasks exist', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = loadedState;
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.querySelector('.crop-detail__blueprint-add-form')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('#blueprint-task-picker')).toBeTruthy();
    expect(
      fixture.nativeElement.querySelector('.crop-detail__template-add-actions .btn-primary')
    ).toBeTruthy();
  });

  it('explains all master tasks are already used when picker is empty but blueprints exist', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            manual_blueprint_add: {
              no_unassociated_tasks_all_used:
                'All master tasks are already in this task plan.',
              go_to_create: 'Create a task'
            }
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = withCropDetailDisplayState({
      ...loadedState,
      agriculturalTasks: [loadedState.agriculturalTasks[0]]
    });
    fixture.detectChanges();
    await fixture.whenStable();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('All master tasks are already in this task plan.');
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
    component.control = withCropDetailDisplayState({
      ...readyState,
      blueprintRegenerateError: 'crops.show.blueprint_errors.generic'
    });
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

    component.control = { ...readyState, blueprintsLoading: false };
    fixture.detectChanges();
    await Promise.resolve();
    await fixture.whenStable();

    expect(getElementById).toHaveBeenCalledWith('blueprints-heading');
    expect(scrollIntoView).toHaveBeenCalledWith({ behavior: 'smooth', block: 'start' });

    getElementById.mockRestore();
    mockActivatedRoute.snapshot.fragment = null;
  });
});
