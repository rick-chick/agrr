import { CdkDragDrop } from '@angular/cdk/drag-drop';
import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import en from '../../../../assets/i18n/en.json';
import { CropTaskScheduleBlueprintsComponent } from './crop-task-schedule-blueprints.component';
import type { CropTaskScheduleBlueprintsViewState } from './crop-task-schedule-blueprints.view';
import { CropTaskScheduleBlueprintsPresenter } from '../../../adapters/crops/crop-task-schedule-blueprints.presenter';
import { LoadCropDetailUseCase } from '../../../usecase/crops/load-crop-detail.usecase';
import { LoadAgriculturalTaskListUseCase } from '../../../usecase/agricultural-tasks/load-agricultural-task-list.usecase';
import { LoadCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/load-crop-task-schedule-blueprints.usecase';
import { CreateCropTaskScheduleBlueprintUseCase } from '../../../usecase/crops/create-crop-task-schedule-blueprint.usecase';
import { RegenerateCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/regenerate-crop-task-schedule-blueprints.usecase';
import { UpdateCropTaskScheduleBlueprintUseCase } from '../../../usecase/crops/update-crop-task-schedule-blueprint.usecase';
import { DeleteCropTaskScheduleBlueprintUseCase } from '../../../usecase/crops/delete-crop-task-schedule-blueprint.usecase';
import { withCropBlueprintDisplayState } from '../../../adapters/crops/crop-blueprints-display-state';
import {
  defaultBlueprintReadiness
} from '../../../domain/crops/blueprint-generation-readiness';
import type { CropTaskScheduleBlueprint } from '../../../domain/crops/crop-task-schedule-blueprint';

const loadedState: CropTaskScheduleBlueprintsViewState = withCropBlueprintDisplayState({
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
  blueprintGddTouched: {},
  blueprintStageLanes: [],
  cumulativeGddTimelineSegments: [],
  blueprintGddErrors: {},
  blueprintLaneOutOfRangeCounts: {},
  blueprintCreateGddError: null,
  blueprintCreateFormAttempted: false,
  selectedStageGddRange: null,
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
    }
  ]
};

const readyState: CropTaskScheduleBlueprintsViewState = withCropBlueprintDisplayState({
  ...loadedState,
  crop: cropWithReadyStages
});

describe('CropTaskScheduleBlueprintsComponent', () => {
  let fixture: ComponentFixture<CropTaskScheduleBlueprintsComponent>;
  let component: CropTaskScheduleBlueprintsComponent;
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let loadAgriculturalTasksUseCase: { execute: ReturnType<typeof vi.fn> };
  let loadBlueprintsUseCase: { execute: ReturnType<typeof vi.fn> };
  let createBlueprintUseCase: { execute: ReturnType<typeof vi.fn> };
  let regenerateBlueprintsUseCase: { execute: ReturnType<typeof vi.fn> };
  let updateBlueprintUseCase: { execute: ReturnType<typeof vi.fn>; executeDrop: ReturnType<typeof vi.fn> };
  let deleteBlueprintUseCase: { execute: ReturnType<typeof vi.fn> };
  let presenter: CropTaskScheduleBlueprintsPresenter;
  let mockActivatedRoute: {
    snapshot: {
      paramMap: { get: ReturnType<typeof vi.fn> };
      queryParamMap: { get: ReturnType<typeof vi.fn> };
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
    presenter = new CropTaskScheduleBlueprintsPresenter();
    mockActivatedRoute = {
      snapshot: {
        paramMap: { get: vi.fn(() => '3') },
        queryParamMap: { get: vi.fn(() => null) }
      }
    };

    TestBed.overrideComponent(CropTaskScheduleBlueprintsComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadCropDetailUseCase, useValue: loadUseCase },
          { provide: LoadAgriculturalTaskListUseCase, useValue: loadAgriculturalTasksUseCase },
          { provide: LoadCropTaskScheduleBlueprintsUseCase, useValue: loadBlueprintsUseCase },
          { provide: RegenerateCropTaskScheduleBlueprintsUseCase, useValue: regenerateBlueprintsUseCase },
          { provide: CreateCropTaskScheduleBlueprintUseCase, useValue: createBlueprintUseCase },
          { provide: UpdateCropTaskScheduleBlueprintUseCase, useValue: updateBlueprintUseCase },
          { provide: DeleteCropTaskScheduleBlueprintUseCase, useValue: deleteBlueprintUseCase },
          { provide: CropTaskScheduleBlueprintsPresenter, useValue: presenter },
          { provide: ChangeDetectorRef, useValue: { markForCheck: vi.fn() } },
          { provide: ActivatedRoute, useValue: mockActivatedRoute }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [CropTaskScheduleBlueprintsComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(CropTaskScheduleBlueprintsComponent);
    component = fixture.componentInstance;
    presenter.setView(component);
  });

  it('loads crop detail and task sections on init', () => {
    const setViewSpy = vi.spyOn(presenter, 'setView');
    component.ngOnInit();
    expect(setViewSpy).toHaveBeenCalledWith(component);
    expect(loadUseCase.execute).toHaveBeenCalledWith({ cropId: 3 });
    expect(loadAgriculturalTasksUseCase.execute).toHaveBeenCalled();
    expect(loadBlueprintsUseCase.execute).toHaveBeenCalledWith({ cropId: 3 });
  });

  it('shows page header with crop name and back link to crop detail', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = readyState;
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.querySelector('.page-title')?.textContent).toContain('Tomato');
    expect(fixture.nativeElement.querySelector('a[href="/crops/3"]')).toBeTruthy();
  });

  it('uses from-plan description when fromPlan query param is set', async () => {
    const fromPlanDescription =
      'Task schedules for this plan are already generated. Edit these templates to adjust future schedules.';
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            task_schedule_blueprints_description_from_plan_html: fromPlanDescription,
            task_schedule_blueprints_description_html: 'Default with blueprints',
            task_schedule_blueprints_description_empty_html: 'Default empty'
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
    component.control = { ...readyState, fromPlanId: 7 };
    fixture.detectChanges();
    await fixture.whenStable();

    const description = fixture.nativeElement.querySelector('.section-card__description');
    expect(description?.textContent).toContain('already generated');
    expect(description?.textContent).not.toContain('Default with blueprints');
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

    expect(fixture.nativeElement.querySelector('a[href*="/plans/7/task_schedule"]')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.crop-blueprints__plan-wizard-banner')).toBeTruthy();
  });

  it('regenerates blueprints after confirm when readiness is satisfied', () => {
    vi.spyOn(window, 'confirm').mockReturnValue(true);
    component.control = readyState;
    component.regenerateBlueprints();
    expect(regenerateBlueprintsUseCase.execute).toHaveBeenCalledWith({ cropId: 3 });
  });

  it('links stage readiness action to crop edit', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            blueprint_readiness: {
              title: 'Required before AI generation',
              stages_missing: 'Growth stages are missing base temperature or required GDD',
              stages_action: 'Configure growth stages'
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

    expect(fixture.nativeElement.querySelector('a[href="/crops/3/stages"]')).toBeTruthy();
  });

  it('requires stage when crop has stages before creating blueprint', () => {
    component.control = withCropBlueprintDisplayState({
      ...readyState,
      selectedBlueprintAgriculturalTaskId: 6
    });
    component.createBlueprint();
    expect(createBlueprintUseCase.execute).not.toHaveBeenCalled();
    expect(component.control.blueprintCreateFormAttempted).toBe(true);
  });

  it('creates blueprint when task and stage are selected', () => {
    component.control = withCropBlueprintDisplayState({
      ...readyState,
      selectedBlueprintAgriculturalTaskId: 6,
      selectedBlueprintStageOrder: 1
    });
    component.createBlueprint();
    expect(createBlueprintUseCase.execute).toHaveBeenCalledWith({
      cropId: 3,
      agriculturalTaskId: 6,
      stageOrder: 1,
      stageName: 'Vegetative',
      gddTrigger: null
    });
  });

  it('delegates blueprint drop to update use case with crop context', () => {
    fixture.detectChanges();
    component.control = readyState;
    fixture.detectChanges();

    const blueprint = readyState.blueprints[0];
    component.onBlueprintDropped(
      {
        previousContainer: { data: readyState.blueprintStageLanes[0]?.blueprints ?? [] },
        container: { data: readyState.blueprintStageLanes[0]?.blueprints ?? [] },
        previousIndex: 0,
        currentIndex: 0,
        item: { data: blueprint }
      } as CdkDragDrop<CropTaskScheduleBlueprint[]>,
      null
    );

    expect(updateBlueprintUseCase.executeDrop).toHaveBeenCalled();
    expect(updateBlueprintUseCase.execute).not.toHaveBeenCalled();
  });

  it('shows lane out-of-range warning when blueprint GDD is outside stage band', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    const outOfRangeState = withCropBlueprintDisplayState({
      ...readyState,
      blueprints: [{ ...readyState.blueprints[0], gdd_trigger: 600 }],
      blueprintGddDrafts: { 20: 600 }
    });

    fixture.detectChanges();
    component.control = outOfRangeState;
    fixture.detectChanges();
    await fixture.whenStable();

    expect(outOfRangeState.blueprintLaneOutOfRangeCounts[1]).toBe(1);
    const warning = fixture.nativeElement.querySelector('.blueprint-stage-lane__lane-warning');
    expect(warning).toBeTruthy();
    expect(warning.textContent).toMatch(/out of range/i);
  });

  it('renders GDD axis when crop has stages with cumulative GDD', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = readyState;
    fixture.detectChanges();
    await fixture.whenStable();

    expect(readyState.cumulativeGddTimelineSegments.length).toBeGreaterThan(0);
    const axis = fixture.nativeElement.querySelector('.blueprint-gdd-axis');
    expect(axis).toBeTruthy();
    expect(axis.getAttribute('role')).toBe('img');
    expect(axis.getAttribute('aria-label')).toContain('500');
    const segment = fixture.nativeElement.querySelector('.blueprint-gdd-axis__segment');
    expect(segment).toBeTruthy();
    expect(segment.textContent).toMatch(/Vegetative/i);
    expect(segment.textContent).toMatch(/from planting/i);
  });

  it('renders GDD intro copy when crop has growth stages', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = readyState;
    fixture.detectChanges();
    await fixture.whenStable();

    const intro = fixture.nativeElement.querySelector('.crop-blueprints__gdd-intro');
    expect(intro).toBeTruthy();
    expect(intro.textContent).toContain(
      translate.instant('crops.show.task_schedule_blueprints_gdd_intro')
    );
  });
});
