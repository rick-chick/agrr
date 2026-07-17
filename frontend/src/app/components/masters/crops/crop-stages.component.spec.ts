import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter, Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, vi } from 'vitest';

import { CropStagesComponent } from './crop-stages.component';
import { CropStage } from '../../../domain/crops/crop';
import { CropStagesPresenter } from '../../../usecase/crops/crop-stages.providers';
import { LoadCropForEditUseCase } from '../../../usecase/crops/load-crop-for-edit.usecase';
import { CreateCropStageUseCase } from '../../../usecase/crops/create-crop-stage.usecase';
import { ReorderCropStagesUseCase } from '../../../usecase/crops/reorder-crop-stages.usecase';
import { LoadCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/load-crop-task-schedule-blueprints.usecase';
import { FlashMessageService } from '../../../services/flash-message.service';
import { AuthService } from '../../../services/auth.service';
import { CdkDragDrop } from '@angular/cdk/drag-drop';
import { defaultBlueprintReadiness } from '../../../domain/crops/blueprint-generation-readiness';

const initialFormData = {
  name: '',
  is_reference: false,
  crop_stages: [] as CropStage[]
};

const loadedControlBase = {
  loading: false,
  error: null,
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  pendingReorderCropStagesSnapshot: null,
  pendingResyncPanelDraft: false,
  taskScheduleBlueprints: [],
  blueprintReadiness: defaultBlueprintReadiness(),
  stageRequirementGaps: [],
  showBlueprintReadinessChecklist: false,
  showNextStepCta: false
};

const stageFixture: CropStage = {
  id: 1,
  name: 'Germination',
  order: 1,
  temperature_requirement: {
    id: 1,
    crop_stage_id: 1,
    base_temperature: 10,
    optimal_min: null,
    optimal_max: null,
    low_stress_threshold: null,
    high_stress_threshold: null,
    frost_threshold: null,
    sterility_risk_threshold: null,
    max_temperature: null
  },
  thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 100 },
  sunshine_requirement: null,
  nutrient_requirement: null
} as CropStage;

const tableTranslations = {
  crops: {
    stage: {
      default_name: 'Stage {{order}}'
    },
    index: { title: 'Crops' },
    show: {
      no_stages_description: 'Add growth stages for this crop.',
      celsius_unit: '°C',
      from_plan_wizard_title: 'From plan wizard',
      from_plan_stages_wizard_lead: 'Configure stages',
      return_to_plan: 'Return to plan',
      blueprint_readiness: {
        detail_title: 'Configuration status',
        stages_page_gap_base_temperature: '{{stageName}}: base temperature not set',
        stages_page_gap_required_gdd: '{{stageName}}: required GDD not set',
        stages_next_step_action: 'Go to task schedule templates'
      }
    },
    errors: {
      invalid_id: 'Invalid crop ID.'
    },
    edit: {
      stages_title: 'Growth Stages',
      stages_lead: 'Configure growth stages.',
      stages_list_heading: 'Stage list',
      stages_empty_lead: 'Stages are required.',
      add_stage: 'Add Stage',
      table_order: 'Order',
      table_optimal_range: 'Optimal temperature range',
      table_base_temperature: 'Base temp',
      optimal_temperature_range: '{{min}}–{{max}} {{unit}}',
      optimal_temperature_value: '{{value}} {{unit}}',
      value_missing: '—',
      stage_order_duplicate: 'Duplicate order: {{orders}}',
      stage_order_duplicate_hint: 'Drag rows to reorder or use the button below to renumber.',
      stage_order_renumber: 'Renumber orders',
      reference_stages_readonly: 'Reference crops are read-only. Only administrators can edit growth stages.'
    }
  },
  common: {
    loading: 'Loading...'
  }
};

describe('CropStagesComponent', () => {
  let component: CropStagesComponent;
  let fixture: ComponentFixture<CropStagesComponent>;
  let mockActivatedRoute: {
    snapshot: {
      paramMap: { get: ReturnType<typeof vi.fn> };
      queryParamMap: { get: ReturnType<typeof vi.fn> };
    };
  };
  let mockRouter: Router;
  let mockLoadUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockCreateCropStageUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockReorderCropStagesUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockLoadBlueprintsUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockFlashMessage: { show: ReturnType<typeof vi.fn> };
  let mockAuthService: { user: ReturnType<typeof vi.fn> };
  let translateService: TranslateService;

  async function loadStages(
    stages: CropStage[],
    cropName = 'Tomato',
    options: { is_reference?: boolean } = {}
  ): Promise<void> {
    const presenter = fixture.debugElement.injector.get(CropStagesPresenter);
    presenter.setView(component);
    presenter.present({
      crop: {
        id: 1,
        name: cropName,
        is_reference: options.is_reference ?? false,
        groups: [],
        crop_stages: stages
      }
    });
    presenter.present({ blueprints: [] });
    fixture.detectChanges();
    await new Promise<void>((resolve) => queueMicrotask(() => resolve()));
    fixture.detectChanges();
  }

  beforeEach(async () => {
    mockActivatedRoute = {
      snapshot: {
        paramMap: {
          get: vi.fn((key: string) => (key === 'id' ? '1' : null))
        },
        queryParamMap: {
          get: vi.fn(() => null)
        }
      }
    };

    mockLoadUseCase = { execute: vi.fn() };
    mockCreateCropStageUseCase = { execute: vi.fn() };
    mockReorderCropStagesUseCase = { execute: vi.fn() };
    mockLoadBlueprintsUseCase = { execute: vi.fn() };
    mockFlashMessage = { show: vi.fn() };
    mockAuthService = { user: vi.fn(() => ({ admin: false })) };

    await TestBed.configureTestingModule({
      imports: [
        CropStagesComponent,
        TranslateModule.forRoot({
          fallbackLang: 'en'
        })
      ],
      providers: [
        provideRouter([]),
        CropStagesPresenter,
        { provide: ActivatedRoute, useValue: mockActivatedRoute },
        { provide: LoadCropForEditUseCase, useValue: mockLoadUseCase },
        { provide: CreateCropStageUseCase, useValue: mockCreateCropStageUseCase },
        { provide: ReorderCropStagesUseCase, useValue: mockReorderCropStagesUseCase },
        { provide: LoadCropTaskScheduleBlueprintsUseCase, useValue: mockLoadBlueprintsUseCase },
        { provide: FlashMessageService, useValue: mockFlashMessage },
        { provide: AuthService, useValue: mockAuthService }
      ]
    })
      .overrideComponent(CropStagesComponent, { set: { providers: [] } })
      .compileComponents();

    TestBed.overrideProvider(LoadCropForEditUseCase, { useValue: mockLoadUseCase });
    TestBed.overrideProvider(CreateCropStageUseCase, { useValue: mockCreateCropStageUseCase });
    TestBed.overrideProvider(ReorderCropStagesUseCase, { useValue: mockReorderCropStagesUseCase });
    TestBed.overrideProvider(LoadCropTaskScheduleBlueprintsUseCase, { useValue: mockLoadBlueprintsUseCase });

    fixture = TestBed.createComponent(CropStagesComponent);
    component = fixture.componentInstance;
    mockRouter = TestBed.inject(Router);
    vi.spyOn(mockRouter, 'navigate').mockResolvedValue(true);
    translateService = TestBed.inject(TranslateService);
    translateService.setTranslation('en', tableTranslations, true);
    translateService.use('en');
  });

  it('should load crop and task schedule blueprints on init', () => {
    expect(component.cropId).toBe(1);
    fixture.detectChanges();
    expect(mockLoadUseCase.execute).toHaveBeenCalledWith({ cropId: 1 });
    expect(mockLoadBlueprintsUseCase.execute).toHaveBeenCalledWith({ cropId: 1 });
  });

  it('shows invalid crop id error and skips API calls for non-numeric route id', () => {
    mockActivatedRoute.snapshot.paramMap.get.mockImplementation((key: string) =>
      key === 'id' ? 'abc' : null
    );

    fixture.detectChanges();

    expect(component.control.error).toBe('crops.errors.invalid_id');
    expect(component.control.showNextStepCta).toBe(false);
    expect(fixture.nativeElement.querySelector('.master-load-error')).toBeTruthy();
    expect(fixture.nativeElement.querySelectorAll('app-master-context-header').length).toBe(1);
    expect(fixture.nativeElement.querySelector('.master-context-header__forward')).toBeNull();
    expect(mockLoadUseCase.execute).not.toHaveBeenCalled();
    expect(mockLoadBlueprintsUseCase.execute).not.toHaveBeenCalled();
  });

  it('derives display state when control is assigned through the component setter', () => {
    const incompleteStage: CropStage = {
      id: 2,
      name: 'Vegetative',
      order: 2
    } as CropStage;

    component.control = {
      ...loadedControlBase,
      formData: {
        name: 'Tomato',
        is_reference: false,
        crop_stages: [incompleteStage]
      }
    };

    expect(component.control.showBlueprintReadinessChecklist).toBe(true);
    expect(component.control.showNextStepCta).toBe(false);
  });

  it('derives display state when presenter loads crop data', () => {
    const presenter = fixture.debugElement.injector.get(CropStagesPresenter);
    presenter.setView(component);
    const incompleteStage: CropStage = {
      id: 2,
      name: 'Vegetative',
      order: 2
    } as CropStage;

    presenter.present({
      crop: {
        id: 1,
        name: 'Tomato',
        is_reference: false,
        groups: [],
        crop_stages: [incompleteStage]
      }
    });
    presenter.present({ blueprints: [] });

    expect(component.control.showBlueprintReadinessChecklist).toBe(true);
    expect(component.control.showNextStepCta).toBe(false);
  });

  it('shows load error panel and hides stage list when initial crop load fails', () => {
    const presenter = fixture.debugElement.injector.get(CropStagesPresenter);
    mockLoadUseCase.execute.mockImplementation(() => {
      presenter.onError({ message: 'common.api_error.not_found' });
    });
    translateService.setTranslation(
      'en',
      {
        ...tableTranslations,
        crops: {
          ...tableTranslations.crops,
          index: { title: 'Crops' }
        },
        common: {
          api_error: {
            not_found: 'Resource not found'
          }
        },
        masters: {
          load_error: {
            retry: 'Retry'
          }
        }
      },
      true
    );
    translateService.use('en');

    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.master-load-error')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Resource not found');
    expect(fixture.nativeElement.querySelectorAll('app-master-context-header').length).toBe(1);
    expect(fixture.nativeElement.querySelector('.master-context-header__forward')).toBeNull();
    expect(component.control.showNextStepCta).toBe(false);
    expect(fixture.nativeElement.querySelector('.crop-stages-section')).toBeFalsy();
    expect(fixture.nativeElement.querySelector('.crop-stages-empty__cta')).toBeFalsy();
    expect(
      (fixture.nativeElement.querySelector('a.master-load-error__back') as HTMLAnchorElement)?.getAttribute(
        'href'
      )
    ).toBe('/crops');
    expect(mockCreateCropStageUseCase.execute).not.toHaveBeenCalled();
  });

  it('should call createCropStageUseCase when addCropStage is called', () => {
    component.addCropStage();
    expect(mockCreateCropStageUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      payload: {
        name: 'Stage 1',
        order: 1
      }
    });
  });

  it('shows header primary add button that calls addCropStage when clicked', async () => {
    await loadStages([stageFixture]);

    const addButton = fixture.nativeElement.querySelector(
      '.section-card__header-actions .btn-primary'
    ) as HTMLButtonElement;
    expect(addButton).toBeTruthy();
    expect(addButton.textContent?.trim()).toBe('Add Stage');
    addButton.click();
    expect(mockCreateCropStageUseCase.execute).toHaveBeenCalled();
  });

  it('renders stage cards with optimal range and base temperature metadata only', async () => {
    await loadStages([stageFixture]);

    expect(fixture.nativeElement.querySelector('.section-card')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.card-list')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.crop-stage-card')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Order');
    expect(fixture.nativeElement.textContent).toContain('Optimal temperature range');
    expect(fixture.nativeElement.textContent).toContain('Base temp');
    expect(fixture.nativeElement.textContent).not.toContain('Required GDD');
    expect(fixture.nativeElement.textContent).not.toContain('Cumulative GDD');
  });

  it('does not render edit panel on list page', async () => {
    await loadStages([stageFixture]);

    expect(fixture.nativeElement.querySelector('.crop-stages-edit-panel')).toBeNull();
  });

  it('navigates to stage edit route when stage card is clicked', async () => {
    await loadStages([stageFixture]);

    const card = fixture.nativeElement.querySelector('.crop-stage-card') as HTMLElement;
    card.click();

    expect(mockRouter.navigate).toHaveBeenCalledWith(['/crops', 1, 'stages', 1, 'edit'], {
      queryParams: undefined
    });
  });

  it('navigates to stage edit route with wizard query params when set', async () => {
    mockActivatedRoute.snapshot.queryParamMap.get.mockImplementation((key: string) =>
      key === 'fromPlan' ? '7' : null
    );
    component.fromPlanId = 7;
    await loadStages([stageFixture]);

    const card = fixture.nativeElement.querySelector('.crop-stage-card') as HTMLElement;
    card.click();

    expect(mockRouter.navigate).toHaveBeenCalledWith(['/crops', 1, 'stages', 1, 'edit'], {
      queryParams: { fromPlan: 7, returnTo: 'task_schedule' }
    });
  });

  it('navigates to new stage edit after create succeeds', async () => {
    await loadStages([]);

    component.addCropStage();
    const presenter = fixture.debugElement.injector.get(CropStagesPresenter);
    presenter.present({
      stage: { id: 1, name: 'Stage 1', order: 1 } as CropStage
    });
    await new Promise<void>((resolve) => queueMicrotask(() => resolve()));

    expect(mockRouter.navigate).toHaveBeenCalledWith(['/crops', 1, 'stages', 1, 'edit'], {
      queryParams: undefined
    });
  });

  it('shows em dash for missing optimal range and base temperature in stage card', async () => {
    await loadStages([
      {
        id: 1,
        name: 'Stage 1',
        order: 1,
        temperature_requirement: null,
        thermal_requirement: null,
        sunshine_requirement: null,
        nutrient_requirement: null
      } as CropStage
    ]);

    const card = fixture.nativeElement.querySelector('.crop-stage-card');
    expect(card.textContent).toContain('—');
    expect(card.textContent).not.toContain('Enter required GDD to display the range');
  });

  it('shows optimal temperature range when both min and max are set', async () => {
    await loadStages([
      {
        ...stageFixture,
        temperature_requirement: {
          ...stageFixture.temperature_requirement!,
          optimal_min: 15,
          optimal_max: 25
        }
      }
    ]);

    const card = fixture.nativeElement.querySelector('.crop-stage-card');
    expect(card.textContent).toContain('15–25 °C');
    expect(card.textContent).toContain('10');
  });

  it('shows single-sided optimal temperature when only min or max is set', async () => {
    await loadStages([
      {
        ...stageFixture,
        temperature_requirement: {
          ...stageFixture.temperature_requirement!,
          optimal_min: 15,
          optimal_max: null
        }
      },
      {
        ...stageFixture,
        id: 2,
        name: 'Flowering',
        order: 2,
        temperature_requirement: {
          ...stageFixture.temperature_requirement!,
          id: 2,
          crop_stage_id: 2,
          optimal_min: null,
          optimal_max: 25
        }
      }
    ]);

    const cards = fixture.nativeElement.querySelectorAll('.crop-stage-card');
    expect(cards[0]?.textContent).toContain('15 °C');
    expect(cards[1]?.textContent).toContain('25 °C');
  });

  it('should link back to crop detail via breadcrumbs', async () => {
    await loadStages([], 'Tomato');

    const pageMain = fixture.nativeElement.querySelector('.page-main');
    const breadcrumb = pageMain?.querySelector(':scope > app-master-context-header');
    const pageHeader = pageMain?.querySelector(':scope > .page-header');
    expect(breadcrumb).toBeTruthy();
    expect(pageHeader).toBeTruthy();

    const backLink = breadcrumb?.querySelector('a.master-context-header__back') as HTMLAnchorElement;
    expect(backLink?.getAttribute('href')).toBe('/crops');

    const cropDetailLink = breadcrumb?.querySelector('a.master-context-header__link') as HTMLAnchorElement;
    expect(cropDetailLink?.getAttribute('href')).toBe('/crops/1');
    expect(cropDetailLink?.textContent?.trim()).toBe('Tomato');
  });

  it('shows return-to-plan link when fromPlan query param is set', async () => {
    mockActivatedRoute.snapshot.queryParamMap.get.mockImplementation((key: string) =>
      key === 'fromPlan' ? '7' : null
    );
    component.fromPlanId = 7;
    await loadStages([], 'Tomato');

    expect(fixture.nativeElement.querySelector('a[href*="/plans/7"]')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.crop-stages__return-to-plan')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.crop-blueprints__plan-wizard-banner')).toBeTruthy();
  });

  it('shows empty state with description and header primary add button when no stages', async () => {
    await loadStages([]);

    const empty = fixture.nativeElement.querySelector('.crop-stages-empty');
    expect(empty).toBeTruthy();
    expect(empty?.querySelector('.crop-stages-empty__cta')).toBeNull();
    expect(fixture.nativeElement.querySelector('.card-list')).toBeNull();
    expect(fixture.nativeElement.querySelector('.section-card__header-actions .btn-primary')).toBeTruthy();
  });

  it('shows readiness checklist when stage requirements are incomplete', async () => {
    const incompleteStage: CropStage = {
      id: 2,
      name: 'Vegetative',
      order: 2
    } as CropStage;
    await loadStages([incompleteStage]);

    expect(fixture.nativeElement.querySelector('.blueprint-readiness')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.master-context-header__forward')).toBeNull();
    expect(fixture.nativeElement.textContent).toContain('Vegetative');
    expect(fixture.nativeElement.textContent).toContain('base temperature not set');
  });

  it('shows next-step link in header when all stage requirements are complete', async () => {
    await loadStages([stageFixture]);

    expect(fixture.nativeElement.querySelector('.blueprint-readiness')).toBeNull();
    const nextStep = fixture.nativeElement.querySelector(
      'a.master-context-header__forward'
    ) as HTMLAnchorElement;
    expect(nextStep).toBeTruthy();
    expect(nextStep.classList.contains('btn-secondary')).toBe(false);
    expect(nextStep.getAttribute('href')).toBe('/crops/1/task_schedule_blueprints');
  });

  it('lists missing requirements in fromPlan banner before returning to plan', async () => {
    mockActivatedRoute.snapshot.queryParamMap.get.mockImplementation((key: string) =>
      key === 'fromPlan' ? '7' : null
    );
    component.fromPlanId = 7;
    const incompleteStage: CropStage = {
      id: 2,
      name: 'Vegetative',
      order: 2
    } as CropStage;
    await loadStages([incompleteStage]);

    const gaps = fixture.nativeElement.querySelector('.crop-stages__plan-wizard-gaps');
    expect(gaps).toBeTruthy();
    expect(gaps?.textContent).toContain('Vegetative');
    expect(gaps?.textContent).toContain('base temperature not set');
  });

  it('persists reordered stage orders after drag-drop via handle column', () => {
    component.control = {
      ...loadedControlBase,
      formData: {
        ...initialFormData,
        name: 'Tomato',
        crop_stages: [
          { id: 1, name: 'Stage 1', order: 1 } as CropStage,
          { id: 2, name: 'Stage 2', order: 2 } as CropStage,
          { id: 3, name: 'Stage 3', order: 3 } as CropStage
        ]
      }
    };

    component.onStageDropped({
      previousIndex: 0,
      currentIndex: 2
    } as CdkDragDrop<CropStage[]>);

    expect(component.control.formData.crop_stages.map((stage) => stage.order)).toEqual([1, 2, 3]);
    expect(mockReorderCropStagesUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      entries: [
        { id: 1, order: 3 },
        { id: 2, order: 1 },
        { id: 3, order: 2 }
      ]
    });
  });

  it('rolls back stage order and shows error flash when reorder API fails', () => {
    fixture.detectChanges();
    const presenter = fixture.debugElement.injector.get(CropStagesPresenter);
    const originalStages = [
      { id: 1, name: 'Stage 1', order: 1 } as CropStage,
      { id: 2, name: 'Stage 2', order: 2 } as CropStage
    ];
    component.control = {
      ...loadedControlBase,
      formData: {
        ...initialFormData,
        name: 'Tomato',
        crop_stages: [...originalStages]
      }
    };
    mockReorderCropStagesUseCase.execute.mockImplementation(() => {
      presenter.onError({ message: 'network error' });
    });

    component.onStageDropped({
      previousIndex: 0,
      currentIndex: 1
    } as CdkDragDrop<CropStage[]>);

    expect(component.sortedStages.map((stage) => stage.id)).toEqual([1, 2]);
    expect(component.control.pendingReorderCropStagesSnapshot).toBeNull();
    expect(component.control.pendingErrorFlash).toBeNull();
    expect(mockFlashMessage.show).toHaveBeenCalledWith({
      type: 'error',
      text: 'network error'
    });
  });

  it('shows duplicate order warning', async () => {
    await loadStages([
      { id: 1, name: 'Stage 1', order: 1 } as CropStage,
      { id: 2, name: 'Stage 2', order: 1 } as CropStage
    ]);

    const warning = fixture.nativeElement.querySelector('.crop-stages-order-warning');
    expect(warning?.textContent).toContain('1');
  });

  it('shows renumber button and hint when duplicate orders exist', async () => {
    await loadStages([
      { id: 1, name: 'Stage 1', order: 1 } as CropStage,
      { id: 2, name: 'Stage 2', order: 1 } as CropStage
    ]);

    const warning = fixture.nativeElement.querySelector('.crop-stages-order-warning');
    expect(warning?.textContent).toContain('Drag rows to reorder');
    const button = warning?.querySelector('.crop-stages-order-warning__renumber');
    expect(button?.textContent).toContain('Renumber orders');
  });

  it('renumbers duplicate stage orders via button and persists via reorder use case', async () => {
    await loadStages([
      { id: 1, name: 'Stage 1', order: 1 } as CropStage,
      { id: 2, name: 'Stage 2', order: 1 } as CropStage,
      { id: 3, name: 'Stage 3', order: 3 } as CropStage
    ]);

    component.renumberDuplicateStageOrders();

    expect(component.duplicateStageOrders).toEqual([]);
    expect(component.control.formData.crop_stages.map((stage) => stage.order)).toEqual([1, 2, 3]);
    expect(mockReorderCropStagesUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      entries: [{ id: 2, order: 2 }]
    });
  });

  it('hides duplicate order warning after successful renumber', async () => {
    await loadStages([
      { id: 1, name: 'Stage 1', order: 1 } as CropStage,
      { id: 2, name: 'Stage 2', order: 1 } as CropStage
    ]);

    component.renumberDuplicateStageOrders();
    const presenter = fixture.debugElement.injector.get(CropStagesPresenter);
    presenter.presentReorderCropStages({
      stages: [
        { id: 1, name: 'Stage 1', order: 1 } as CropStage,
        { id: 2, name: 'Stage 2', order: 2 } as CropStage
      ]
    });
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.crop-stages-order-warning')).toBeNull();
  });

  it('disables mutation controls for reference crops when user is not admin', async () => {
    await loadStages([stageFixture], 'Reference Tomato', { is_reference: true });

    expect(fixture.nativeElement.querySelector('.crop-stages__readonly-notice')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.crop-stages-empty__cta')).toBeNull();
    expect(fixture.nativeElement.querySelector('.section-card__header-actions .btn-primary')).toBeNull();
    expect(fixture.nativeElement.querySelector('.crop-stages-edit-panel')).toBeNull();

    component.addCropStage();
    expect(mockCreateCropStageUseCase.execute).not.toHaveBeenCalled();
  });

  it('shows blueprint readiness checklist when required_gdd is 0', async () => {
    await loadStages([
      {
        ...stageFixture,
        thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 0 }
      }
    ]);

    expect(fixture.nativeElement.querySelector('.blueprint-readiness')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.master-context-header__forward')).toBeNull();
    expect(fixture.nativeElement.textContent).toContain('required GDD not set');
  });
});
