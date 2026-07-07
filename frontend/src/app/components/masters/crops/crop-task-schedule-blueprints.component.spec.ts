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
  blueprintSectionDescriptionKey: null,
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

  it('hides section lead when fromPlan query param is set', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            task_schedule_blueprints_lead: 'Plans use these templates.',
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
    component.control = withCropBlueprintDisplayState({
      ...readyState,
      fromPlanId: 7
    });
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.querySelector('.crop-blueprints__section-lead')).toBeFalsy();
    expect(fixture.nativeElement.querySelector('.crop-blueprints__plan-wizard-banner')).toBeTruthy();
  });

  it('shows section lead when blueprints exist and not from plan', async () => {
    const lead = 'Plans use these templates.';
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            task_schedule_blueprints_lead: lead
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

    const leadEl = fixture.nativeElement.querySelector('.crop-blueprints__section-lead');
    expect(leadEl?.textContent).toContain(lead);
  });

  it('omits manual add and AI hint paragraphs in favor of form layout', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = readyState;
    fixture.detectChanges();
    await fixture.whenStable();

    const subsectionDescriptions = fixture.nativeElement.querySelectorAll(
      '.crop-blueprints__subsection-description'
    );
    expect(subsectionDescriptions.length).toBe(0);
    const aiButton = fixture.nativeElement.querySelector('.crop-blueprints__blueprint-ai-import button');
    expect(aiButton?.getAttribute('title')).toContain('AI');
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
    component.control = withCropBlueprintDisplayState({
      ...loadedState,
      fromPlanId: 7
    });
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
    expect(segment.textContent).toMatch(/0.?500/i);
    expect(segment.textContent).toMatch(/℃·day/i);
  });

  it('renders GDD axis caption when crop has growth stages', async () => {
    const caption = 'Cumulative from crop start (not from stage start).';
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            task_schedule_blueprints_gdd_axis_caption: caption,
            task_schedule_blueprints_gdd_axis_label: 'Cumulative GDD (total {{total}} ℃·day)',
            blueprint_stage_lane: {
              gdd_range: '{{start}}–{{end}} ℃·day'
            }
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

    const axisCaption = fixture.nativeElement.querySelector('.blueprint-gdd-axis__caption');
    expect(axisCaption).toBeTruthy();
    expect(axisCaption.textContent).toContain(caption);
    expect(fixture.nativeElement.querySelector('.crop-blueprints__gdd-intro')).toBeFalsy();
  });

  it('shows GDD validation message in DOM when draft is touched and invalid', async () => {
    const outOfRangeMessage = 'GDD must be between 0 and 500.';
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            blueprint_gdd_errors: { out_of_range: outOfRangeMessage },
            gdd_trigger: 'GDD trigger',
            gdd_unit: '℃·day'
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    const invalidState = withCropBlueprintDisplayState({
      ...readyState,
      blueprints: [{ ...readyState.blueprints[0], gdd_trigger: 600 }],
      blueprintGddDrafts: { 20: 600 },
      blueprintGddTouched: { 20: true }
    });

    fixture.detectChanges();
    component.control = invalidState;
    fixture.detectChanges();
    await fixture.whenStable();

    const errorEl = fixture.nativeElement.querySelector('#gdd-error-20');
    expect(errorEl).toBeTruthy();
    expect(errorEl.textContent).toContain(outOfRangeMessage);
  });

  it('sets GDD input placeholder from stage cumulative range when trigger is unset', async () => {
    const placeholder = 'Enter cumulative GDD';
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            gdd_trigger_placeholder: placeholder,
            gdd_trigger: 'GDD trigger',
            gdd_unit: '℃·day',
            blueprint_gdd_unset: 'Not set'
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    const unsetGddState = withCropBlueprintDisplayState({
      ...readyState,
      blueprints: [{ ...readyState.blueprints[0], gdd_trigger: null }],
      blueprintGddDrafts: { 20: null }
    });

    fixture.detectChanges();
    component.control = unsetGddState;
    fixture.detectChanges();
    await fixture.whenStable();

    const input = fixture.nativeElement.querySelector('#gdd-20') as HTMLInputElement | null;
    expect(input).toBeTruthy();
    expect(input?.getAttribute('placeholder')).toBe('0');
  });

  it('shows regenerate retry button when showBlueprintRegenerateRetry is true', async () => {
    const retryLabel = 'Try again';
    const errorMessage = 'Blueprint generation failed.';
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            blueprint_errors: {
              generic: errorMessage,
              retry_action: retryLabel
            }
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    const retryState = withCropBlueprintDisplayState({
      ...readyState,
      blueprintRegenerateError: 'crops.show.blueprint_errors.generic'
    });
    expect(retryState.showBlueprintRegenerateRetry).toBe(true);

    fixture.detectChanges();
    component.control = retryState;
    fixture.detectChanges();
    await fixture.whenStable();

    const alert = fixture.nativeElement.querySelector('.blueprint-regenerate-error');
    expect(alert?.textContent).toContain(errorMessage);
    const retryButton = fixture.nativeElement.querySelector(
      '.blueprint-regenerate-error button.btn-secondary'
    );
    expect(retryButton).toBeTruthy();
    expect(retryButton.textContent).toContain(retryLabel);
  });

  it('hides regenerate retry button when showBlueprintRegenerateRetry is false', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            blueprint_errors: {
              missing_blueprints: 'Add a field-work blueprint first.',
              retry_action: 'Try again'
            }
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    const noRetryState = withCropBlueprintDisplayState({
      ...readyState,
      blueprintRegenerateError: 'crops.show.blueprint_errors.missing_blueprints'
    });
    expect(noRetryState.showBlueprintRegenerateRetry).toBe(false);

    fixture.detectChanges();
    component.control = noRetryState;
    fixture.detectChanges();
    await fixture.whenStable();

    expect(
      fixture.nativeElement.querySelector('.blueprint-regenerate-error button.btn-secondary')
    ).toBeFalsy();
  });

  it('shows invalid crop id error on init when route id is missing', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      { crops: { errors: { invalid_id: 'Invalid crop ID' } } },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');
    mockActivatedRoute.snapshot.paramMap.get.mockReturnValue(null);

    component.ngOnInit();

    expect(component.control.error).toBe('Invalid crop ID');
    expect(loadUseCase.execute).not.toHaveBeenCalled();
  });

  it('control setter recomputes derived display state on partial updates', () => {
    component.control = withCropBlueprintDisplayState({
      ...loadedState,
      crop: cropWithReadyStages,
      blueprints: []
    });
    expect(component.control.blueprintSectionDescriptionKey).toBeNull();

    component.control = {
      ...component.control,
      blueprints: loadedState.blueprints
    };

    expect(component.control.blueprintSectionDescriptionKey).toBe(
      'crops.show.task_schedule_blueprints_lead'
    );
  });
});
