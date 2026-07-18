import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { CropDetailComponent } from './crop-detail.component';
import type { CropDetailViewState } from './crop-detail.view';
import { CropDetailPresenter } from '../../../usecase/crops/crop-detail.providers';
import { LoadCropDetailUseCase } from '../../../usecase/crops/load-crop-detail.usecase';
import { DeleteCropUseCase } from '../../../usecase/crops/delete-crop.usecase';
import { LoadCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/load-crop-task-schedule-blueprints.usecase';
import {
  defaultBlueprintReadiness,
  withCropDetailSummaryState
} from '../../../adapters/crops/crop-detail-presenter.helpers';

const loadedState: CropDetailViewState = withCropDetailSummaryState(
  {
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
      crop_stages: [
        {
          id: 1,
          crop_id: 3,
          name: 'Vegetative',
          order: 1,
          thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 500 }
        }
      ],
      created_at: null,
      updated_at: null
    },
    pendingUndoToast: null,
    pendingErrorFlash: null,
    pendingSuccessFlash: null,
    blueprintsLoading: false,
    blueprintCount: 1,
    blueprintReadiness: defaultBlueprintReadiness(),
    blueprintSummary: null,
    stageBoardColumns: [],
    cumulativeGddTimelineSegments: []
  },
  [
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
      source: 'manual',
      priority: 1,
      amount: null,
      amount_unit: null,
      description: null,
      weather_dependency: null,
      time_per_sqm: null,
      name: 'Weeding'
    }
  ]
);

describe('CropDetailComponent', () => {
  let fixture: ComponentFixture<CropDetailComponent>;
  let component: CropDetailComponent;
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let loadBlueprintsUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: { setView: ReturnType<typeof vi.fn> };
  let mockActivatedRoute: {
    snapshot: {
      paramMap: { get: ReturnType<typeof vi.fn> };
    };
  };

  beforeEach(async () => {
    loadUseCase = { execute: vi.fn() };
    loadBlueprintsUseCase = { execute: vi.fn() };
    mockPresenter = { setView: vi.fn() };
    mockActivatedRoute = {
      snapshot: {
        paramMap: { get: vi.fn(() => '3') }
      }
    };

    TestBed.overrideComponent(CropDetailComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadCropDetailUseCase, useValue: loadUseCase },
          { provide: DeleteCropUseCase, useValue: { execute: vi.fn() } },
          { provide: LoadCropTaskScheduleBlueprintsUseCase, useValue: loadBlueprintsUseCase },
          { provide: CropDetailPresenter, useValue: mockPresenter },
          { provide: ChangeDetectorRef, useValue: { markForCheck: vi.fn() } },
          { provide: ActivatedRoute, useValue: mockActivatedRoute }
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

  it('loads crop detail and blueprint summary on init', () => {
    component.ngOnInit();
    expect(mockPresenter.setView).toHaveBeenCalledWith(component);
    expect(loadUseCase.execute).toHaveBeenCalledWith({ cropId: 3 });
    expect(loadBlueprintsUseCase.execute).toHaveBeenCalledWith({ cropId: 3 });
  });

  it('shows error message when control has error and no crop', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      { crops: { errors: { invalid_id: 'Invalid crop ID' } } },
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
      blueprintsLoading: false
    };
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.querySelector('.master-error')?.textContent).toContain('Invalid crop ID');
    expect(fixture.nativeElement.querySelector('a.master-context-header__back')).toBeTruthy();
  });

  it('shows master context header and omits back button from detail-card__actions', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          index: { title: 'Crops' },
          show: {
            name: 'Name',
            region: 'Region',
            cultivation_template_title: 'Cultivation template',
            task_schedule_blueprints_lead: 'Lead',
            blueprint_readiness: {
              detail_title: 'Status',
              stages_ready: 'Stages ready',
              blueprints_ready: 'Ready'
            },
            blueprint_summary: {
              count: '{{count}} task plan(s)',
              edit_action: 'Edit task plans'
            }
          },
          form: { region_jp: 'Japan' }
        },
        common: { edit: 'Edit', delete: 'Delete' }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = loadedState;
    fixture.detectChanges();
    await fixture.whenStable();

    const backLink = fixture.nativeElement.querySelector(
      'a.master-context-header__back'
    ) as HTMLAnchorElement;
    expect(backLink?.getAttribute('href')).toBe('/crops');
    expect(backLink?.textContent?.trim()).toContain('Crops');
    expect(fixture.nativeElement.querySelector('[aria-current="page"]')?.textContent?.trim()).toBe(
      'Tomato'
    );
    expect(
      fixture.nativeElement.querySelectorAll('.detail-card__actions a.btn-secondary')
    ).toHaveLength(0);
  });

  it('renders unified cultivation template section with task link', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            cultivation_template_title: 'Cultivation template',
            task_schedule_blueprints_lead: 'Schedules are generated from these templates.',
            blueprint_readiness: {
              detail_title: 'Configuration status',
              stages_ready: 'Stages ready',
              blueprints_ready: 'Task plans ready'
            },
            blueprint_summary: {
              count: '{{count}} task plan(s)',
              attention_suffix: '({{count}} need attention)',
              edit_action: 'Edit task plans',
              empty_on_detail: 'No task plans in this stage yet.'
            },
            stage_required_gdd_label: 'Required GDD for this stage',
            gdd_unit: '°C·day',
            celsius_unit: '°C',
            optimal_temperature: 'Optimal temperature',
            blueprint_stage_lane: {
              gdd_range: '{{start}}–{{end}} °C·day',
              board_label: 'Task plans by stage'
            },
            task_schedule_blueprints_gdd_axis_caption: 'Cumulative from crop start',
            task_schedule_blueprints_gdd_axis_label: 'Total {{total}} °C·day',
            unnamed_blueprint: '(Unnamed task)'
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

    expect(fixture.nativeElement.querySelectorAll('.crop-detail__cultivation-template')).toHaveLength(1);
    expect(fixture.nativeElement.querySelector('#cultivation-template-heading')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Cultivation template');
    expect(fixture.nativeElement.textContent).toContain('Cumulative from crop start');
    expect(fixture.nativeElement.textContent).toContain('Configuration status');
    const link = fixture.nativeElement.querySelector(
      '.crop-detail__task-schedules-card .section-card__header-actions a[href="/crops/3/task_schedule_blueprints"]'
    ) as HTMLAnchorElement | null;
    expect(link).toBeTruthy();
    expect(link?.textContent).toContain('Edit task plans');
    expect(fixture.nativeElement.textContent).toContain('Weeding');
    expect(fixture.nativeElement.querySelector('.crop-detail__stage-task-badge')).toBeTruthy();
  });

  it('links blueprint readiness checklist actions when setup is incomplete', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            cultivation_template_title: 'Cultivation template',
            task_schedule_blueprints_lead: 'Lead',
            blueprint_readiness: {
              detail_title: 'Configuration status',
              stages_missing: 'Growth stages are missing base temperature or required GDD',
              stages_action: 'Configure growth stages',
              blueprints_missing: 'No task plans registered yet',
              blueprints_action: 'Register task plans'
            },
            blueprint_summary: {
              count: '{{count}} task plan(s)',
              setup_required: 'Growth stages or task plans are not fully configured yet.',
              edit_action: 'Edit task plans',
              empty_on_detail: 'No task plans in this stage yet.'
            },
            stage_required_gdd_label: 'Required GDD for this stage',
            gdd_unit: '°C·day',
            blueprint_stage_lane: {
              gdd_range: '{{start}}–{{end}} °C·day',
              board_label: 'Task plans by stage'
            }
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = withCropDetailSummaryState(
      {
        ...loadedState,
        blueprintCount: 0,
        blueprintReadiness: defaultBlueprintReadiness()
      },
      []
    );
    fixture.detectChanges();
    await fixture.whenStable();

    const stagesLink = fixture.nativeElement.querySelector(
      '.blueprint-readiness a[href="/crops/3/stages"]'
    ) as HTMLAnchorElement | null;
    const blueprintsLink = fixture.nativeElement.querySelector(
      '.blueprint-readiness a[href="/crops/3/task_schedule_blueprints"]'
    ) as HTMLAnchorElement | null;

    expect(stagesLink).toBeTruthy();
    expect(stagesLink?.textContent).toContain('Configure growth stages');
    expect(blueprintsLink).toBeTruthy();
    expect(blueprintsLink?.textContent).toContain('Register task plans');
  });

  it('places edit actions in each cultivation subsection card header', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            cultivation_template_title: 'Cultivation template',
            task_schedule_blueprints_lead: 'Schedules are generated from these templates.',
            stages_title: 'Growth Stages',
            task_schedule_blueprints_title: 'Task Plan Templates',
            blueprint_readiness: {
              detail_title: 'Configuration status',
              stages_ready: 'Stages ready',
              blueprints_ready: 'Task plans ready',
              stages_edit_action: 'Edit growth stages',
              stages_action: 'Configure growth stages'
            },
            blueprint_summary: {
              count: '{{count}} task plan(s)',
              edit_action: 'Edit task plans',
              empty_on_detail: 'No task plans in this stage yet.'
            },
            stage_required_gdd_label: 'Required GDD for this stage',
            gdd_unit: '°C·day',
            blueprint_stage_lane: {
              gdd_range: '{{start}}–{{end}} °C·day',
              board_label: 'Task plans by stage'
            },
            unnamed_blueprint: '(Unnamed task)'
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
      blueprintReadiness: {
        ...defaultBlueprintReadiness(),
        stageRequirementsReady: true,
        blueprintsReady: true,
        ready: true
      }
    };
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.querySelector('.crop-detail__cultivation-actions')).toBeNull();

    const stagesHeader = fixture.nativeElement.querySelector(
      '.crop-detail__stages-card .section-card__header-actions'
    );
    const taskSchedulesHeader = fixture.nativeElement.querySelector(
      '.crop-detail__task-schedules-card .section-card__header-actions'
    );
    expect(stagesHeader).toBeTruthy();
    expect(taskSchedulesHeader).toBeTruthy();
    expect(stagesHeader?.textContent).toContain('Growth Stages');
    expect(taskSchedulesHeader?.textContent).toContain('Task Plan Templates');

    const stagesLink = stagesHeader?.querySelector(
      'a[href="/crops/3/stages"]'
    ) as HTMLAnchorElement | null;
    const taskSchedulesLink = taskSchedulesHeader?.querySelector(
      'a[href="/crops/3/task_schedule_blueprints"]'
    ) as HTMLAnchorElement | null;

    expect(stagesLink).toBeTruthy();
    expect(stagesLink?.textContent).toContain('Edit growth stages');
    expect(taskSchedulesLink).toBeTruthy();
    expect(taskSchedulesLink?.textContent).toContain('Edit task plans');

    for (const link of [stagesLink, taskSchedulesLink]) {
      expect(link?.classList.contains('btn-secondary')).toBe(true);
      expect(link?.classList.contains('btn-primary')).toBe(false);
    }
  });

  it('groups tasks with the same gdd trigger into one badge row', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            cultivation_template_title: 'Cultivation template',
            task_schedule_blueprints_lead: 'Lead',
            blueprint_readiness: {
              detail_title: 'Status',
              stages_ready: 'Stages ready',
              blueprints_ready: 'Ready',
              stages_edit_action: 'Edit growth stages',
              stages_action: 'Configure growth stages'
            },
            blueprint_summary: {
              count: '{{count}} task plan(s)',
              edit_action: 'Edit task plans',
              empty_on_detail: 'No task plans in this stage yet.'
            },
            stage_required_gdd_label: 'Required GDD for this stage',
            gdd_unit: '°C·day',
            blueprint_stage_lane: {
              gdd_range: '{{start}}–{{end}} °C·day',
              board_label: 'Task plans by stage'
            },
            unnamed_blueprint: '(Unnamed task)'
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = withCropDetailSummaryState(
      {
        ...loadedState,
        blueprintCount: 3,
        blueprintReadiness: { ...defaultBlueprintReadiness(), blueprintsReady: true, ready: true }
      },
      [
        {
          id: 20,
          crop_id: 3,
          agricultural_task_id: 5,
          source_agricultural_task_id: null,
          stage_order: 1,
          stage_name: 'Vegetative',
          gdd_trigger: 200,
          gdd_tolerance: null,
          task_type: 'field_work',
          source: 'manual',
          priority: 1,
          amount: null,
          amount_unit: null,
          description: null,
          weather_dependency: null,
          time_per_sqm: null,
          name: 'Planting'
        },
        {
          id: 21,
          crop_id: 3,
          agricultural_task_id: 6,
          source_agricultural_task_id: null,
          stage_order: 1,
          stage_name: 'Vegetative',
          gdd_trigger: 200,
          gdd_tolerance: null,
          task_type: 'field_work',
          source: 'manual',
          priority: 2,
          amount: null,
          amount_unit: null,
          description: null,
          weather_dependency: null,
          time_per_sqm: null,
          name: 'Tilling'
        },
        {
          id: 22,
          crop_id: 3,
          agricultural_task_id: 7,
          source_agricultural_task_id: null,
          stage_order: 1,
          stage_name: 'Vegetative',
          gdd_trigger: 200,
          gdd_tolerance: null,
          task_type: 'field_work',
          source: 'manual',
          priority: 3,
          amount: null,
          amount_unit: null,
          description: null,
          weather_dependency: null,
          time_per_sqm: null,
          name: 'Basal fertilizer'
        }
      ]
    );
    fixture.detectChanges();
    await fixture.whenStable();

    const gddLabels = fixture.nativeElement.querySelectorAll(
      '.crop-detail__stage-task-group-label'
    );
    expect(gddLabels).toHaveLength(1);
    expect(gddLabels[0].textContent).toContain('200');
    expect(fixture.nativeElement.querySelectorAll('.crop-detail__stage-task-badge')).toHaveLength(
      3
    );
    expect(fixture.nativeElement.textContent).toContain('Planting');
    expect(fixture.nativeElement.textContent).toContain('Tilling');
    expect(fixture.nativeElement.textContent).toContain('Basal fertilizer');
  });

  it('shows attention suffix when blueprint summary has attention items', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            cultivation_template_title: 'Cultivation template',
            task_schedule_blueprints_lead: 'Lead',
            blueprint_readiness: {
              detail_title: 'Status',
              stages_ready: 'Stages ready',
              blueprints_ready: 'Ready',
              blueprints_missing: 'Missing',
              stages_edit_action: 'Edit growth stages',
              stages_action: 'Configure growth stages'
            },
            blueprint_summary: {
              count: '{{count}} task plan(s)',
              attention_suffix: '({{count}} need attention)',
              edit_action: 'Edit task plans',
              empty_on_detail: 'No task plans in this stage yet.'
            },
            blueprint_gdd_unset: 'Timing unset',
            stage_required_gdd_label: 'Required GDD for this stage',
            gdd_unit: '°C·day',
            blueprint_stage_lane: {
              gdd_range: '{{start}}–{{end}} °C·day',
              gdd_range_missing: 'Required GDD missing',
              board_label: 'Task plans by stage'
            },
            unnamed_blueprint: '(Unnamed task)'
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = withCropDetailSummaryState(
      {
        ...loadedState,
        blueprintCount: 1
      },
      [
        {
          id: 21,
          crop_id: 3,
          agricultural_task_id: 5,
          source_agricultural_task_id: null,
          stage_order: 1,
          stage_name: 'Vegetative',
          gdd_trigger: null,
          gdd_tolerance: null,
          task_type: 'field_work',
          source: 'manual',
          priority: 1,
          amount: null,
          amount_unit: null,
          description: null,
          weather_dependency: null,
          time_per_sqm: null,
          name: 'Irrigation'
        }
      ]
    );
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.textContent).toContain('(1 need attention)');
    expect(fixture.nativeElement.textContent).toContain('Timing unset');
  });

  it('applies attention styling to out-of-range blueprint badges', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            cultivation_template_title: 'Cultivation template',
            task_schedule_blueprints_lead: 'Lead',
            blueprint_readiness: {
              detail_title: 'Status',
              stages_ready: 'Stages ready',
              blueprints_ready: 'Ready',
              stages_edit_action: 'Edit growth stages',
              stages_action: 'Configure growth stages'
            },
            blueprint_summary: {
              count: '{{count}} task plan(s)',
              edit_action: 'Edit task plans',
              empty_on_detail: 'No task plans in this stage yet.'
            },
            stage_required_gdd_label: 'Required GDD for this stage',
            gdd_unit: '°C·day',
            blueprint_stage_lane: {
              gdd_range: '{{start}}–{{end}} °C·day',
              board_label: 'Task plans by stage'
            },
            unnamed_blueprint: '(Unnamed task)'
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = withCropDetailSummaryState(loadedState, [
      {
        id: 21,
        crop_id: 3,
        agricultural_task_id: 5,
        source_agricultural_task_id: null,
        stage_order: 1,
        stage_name: 'Vegetative',
        gdd_trigger: 900,
        gdd_tolerance: null,
        task_type: 'field_work',
        source: 'manual',
        priority: 1,
        amount: null,
        amount_unit: null,
        description: null,
        weather_dependency: null,
        time_per_sqm: null,
        name: 'Out of range task'
      }
    ]);
    fixture.detectChanges();
    await fixture.whenStable();

    expect(
      fixture.nativeElement.querySelector('.crop-detail__stage-task-badge--attention')
    ).toBeTruthy();
  });

  it('shows per-column empty message when a stage has no blueprints', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            cultivation_template_title: 'Cultivation template',
            task_schedule_blueprints_lead: 'Lead',
            blueprint_readiness: {
              detail_title: 'Status',
              stages_ready: 'Stages ready',
              stages_missing: 'Stages missing',
              blueprints_ready: 'Ready',
              blueprints_missing: 'Missing',
              stages_edit_action: 'Edit growth stages',
              stages_action: 'Configure growth stages'
            },
            blueprint_summary: {
              count: '{{count}} task plan(s)',
              edit_action: 'Edit task plans',
              empty_on_detail: 'No task plans in this stage yet.'
            },
            stage_required_gdd_label: 'Required GDD for this stage',
            gdd_unit: '°C·day',
            blueprint_stage_lane: {
              gdd_range: '{{start}}–{{end}} °C·day',
              board_label: 'Task plans by stage'
            }
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = withCropDetailSummaryState(
      { ...loadedState, blueprintCount: 0, blueprintReadiness: defaultBlueprintReadiness() },
      []
    );
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.textContent).toContain('No task plans in this stage yet.');
  });

  it('uses edit stages CTA when stage requirements are ready', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            cultivation_template_title: 'Cultivation template',
            task_schedule_blueprints_lead: 'Lead',
            blueprint_readiness: {
              detail_title: 'Status',
              stages_ready: 'Stages ready',
              blueprints_ready: 'Ready',
              stages_edit_action: 'Edit growth stages',
              stages_action: 'Configure growth stages'
            },
            blueprint_summary: {
              count: '{{count}} task plan(s)',
              edit_action: 'Edit task plans',
              empty_on_detail: 'No task plans in this stage yet.'
            },
            stage_required_gdd_label: 'Required GDD for this stage',
            gdd_unit: '°C·day',
            blueprint_stage_lane: {
              gdd_range: '{{start}}–{{end}} °C·day',
              board_label: 'Task plans by stage'
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
      ...loadedState,
      blueprintReadiness: {
        ...defaultBlueprintReadiness(),
        stageRequirementsReady: true,
        blueprintsReady: true,
        ready: true
      }
    };
    fixture.detectChanges();
    await fixture.whenStable();

    const stagesLink = fixture.nativeElement.querySelector(
      '.crop-detail__stages-card .section-card__header-actions a[href="/crops/3/stages"]'
    ) as HTMLAnchorElement | null;
    expect(stagesLink?.textContent).toContain('Edit growth stages');
  });

  it('hides gdd group label when trigger matches cumulative range start', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        crops: {
          show: {
            cultivation_template_title: 'Cultivation template',
            task_schedule_blueprints_lead: 'Lead',
            blueprint_readiness: {
              detail_title: 'Status',
              stages_ready: 'Stages ready',
              blueprints_ready: 'Ready',
              stages_edit_action: 'Edit growth stages',
              stages_action: 'Configure growth stages'
            },
            unnamed_blueprint: '(Unnamed task)'
          }
        }
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = withCropDetailSummaryState(loadedState, [
      {
        id: 20,
        crop_id: 3,
        agricultural_task_id: 5,
        source_agricultural_task_id: null,
        stage_order: 1,
        stage_name: 'Vegetative',
        gdd_trigger: 0,
        gdd_tolerance: null,
        task_type: 'field_work',
        source: 'manual',
        priority: 1,
        amount: null,
        amount_unit: null,
        description: null,
        weather_dependency: null,
        time_per_sqm: null,
        name: 'Sowing'
      }
    ]);
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.querySelectorAll('.crop-detail__stage-task-group-label')).toHaveLength(0);
    expect(fixture.nativeElement.textContent).toContain('Sowing');
  });

  it('formats created_at using the active app language', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('ja', { crops: { show: { created_at: '作成日' } } }, true);
    translate.setDefaultLang('ja');
    translate.use('ja');

    fixture.detectChanges();
    component.control = {
      ...loadedState,
      crop: {
        ...loadedState.crop!,
        created_at: '2026-06-25 09:03:01'
      }
    };
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.textContent).toContain('2026年6月25日 9:03');
  });
});
