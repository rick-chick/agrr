import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, vi } from 'vitest';

import { CropStagesComponent } from './crop-stages.component';
import { CropStage } from '../../../domain/crops/crop';
import { CropStagesPresenter } from '../../../usecase/crops/crop-stages.providers';
import { LoadCropForEditUseCase } from '../../../usecase/crops/load-crop-for-edit.usecase';
import { CreateCropStageUseCase } from '../../../usecase/crops/create-crop-stage.usecase';
import { ReorderCropStagesUseCase } from '../../../usecase/crops/reorder-crop-stages.usecase';
import { DeleteCropStageUseCase } from '../../../usecase/crops/delete-crop-stage.usecase';
import { LoadCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/load-crop-task-schedule-blueprints.usecase';
import { UpdateTemperatureRequirementUseCase } from '../../../usecase/crops/update-temperature-requirement.usecase';
import { SaveCropStagePanelUseCase } from '../../../usecase/crops/save-crop-stage-panel.usecase';
import { SaveCropStageAdvancedDetailsUseCase } from '../../../usecase/crops/save-crop-stage-advanced-details.usecase';
import { defaultBlueprintReadiness } from '../../../domain/crops/blueprint-generation-readiness';
import { FlashMessageService } from '../../../services/flash-message.service';
import { CdkDragDrop } from '@angular/cdk/drag-drop';

const initialFormData = {
  name: '',
  crop_stages: [] as CropStage[]
};

const loadedControlBase = {
  loading: false,
  error: null,
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  blueprintReadiness: defaultBlueprintReadiness(),
  taskScheduleBlueprints: []
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
      default_name: 'Stage {{order}}',
      delete_confirm_message: 'Delete "{{stageName}}"?',
      delete_confirm_blueprint_warning: 'This stage has {{count}} linked task schedule template(s).'
    },
    show: {
      no_stages_description: 'Add growth stages for this crop.',
      from_plan_wizard_title: 'From plan wizard',
      from_plan_stages_wizard_lead: 'Configure stages',
      return_to_plan: 'Return to plan'
    },
    edit: {
      stages_title: 'Growth Stages',
      stages_lead: 'Configure growth stages.',
      stages_list_heading: 'Stage list',
      stages_empty_lead: 'Stages are required.',
      add_stage: 'Add Stage',
      stage_title: 'Stage {{order}}',
      stage_name: 'Stage Name',
      base_temperature: 'Base Temperature',
      base_temperature_placeholder: 'e.g., 5.0',
      base_temperature_help: 'Base temperature help',
      required_gdd: 'Required GDD',
      required_gdd_placeholder: 'e.g., 800.0',
      required_gdd_help: 'Required GDD help',
      save_stage: 'Save',
      edit_temperature_details: 'Edit stress thresholds…',
      edit_sunshine_nutrient: 'Edit sunshine & nutrients…',
      temperature_details_title: 'Stress thresholds',
      advanced_details_title: 'Sunshine & nutrient details',
      unsaved_confirm_message: 'You have unsaved changes. Continue?',
      table_order: 'Order',
      table_stage_name: 'Stage name',
      table_base_temperature: 'Base temp',
      table_required_gdd: 'Required GDD',
      table_cumulative_gdd: 'Cumulative GDD',
      value_missing: '—',
      stage_cumulative_gdd_range: '{{start}}–{{end}} ℃·day (cumulative)',
      optimal_min: 'Optimal min',
      optimal_max: 'Optimal max',
      low_stress_threshold: 'Low stress',
      high_stress_threshold: 'High stress',
      frost_threshold: 'Frost',
      max_temperature: 'Max temp',
      minimum_sunshine_hours: 'Min sunshine',
      target_sunshine_hours: 'Target sunshine',
      daily_uptake_n: 'N',
      daily_uptake_p: 'P',
      daily_uptake_k: 'K',
      region: 'Region',
      sterility_risk_threshold: 'Sterility risk',
      stage_order_duplicate: 'Duplicate order: {{orders}}'
    }
  },
  common: {
    loading: 'Loading...',
    delete: 'Delete',
    cancel: 'Cancel',
    confirm: 'Confirm'
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
  let mockLoadUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockCreateCropStageUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockReorderCropStagesUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockDeleteCropStageUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockLoadBlueprintsUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockUpdateTemperatureRequirementUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockSaveCropStagePanelUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockSaveCropStageAdvancedDetailsUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockFlashMessage: { show: ReturnType<typeof vi.fn> };
  let translateService: TranslateService;

  async function loadStages(stages: CropStage[], cropName = 'Tomato'): Promise<void> {
    component.control = {
      ...loadedControlBase,
      formData: {
        name: cropName,
        crop_stages: stages
      }
    };
    fixture.detectChanges();
    await new Promise<void>((resolve) => queueMicrotask(() => resolve()));
    fixture.detectChanges();
  }

  beforeEach(async () => {
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();

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
    mockDeleteCropStageUseCase = { execute: vi.fn() };
    mockLoadBlueprintsUseCase = { execute: vi.fn() };
    mockUpdateTemperatureRequirementUseCase = { execute: vi.fn() };
    mockSaveCropStagePanelUseCase = { execute: vi.fn() };
    mockSaveCropStageAdvancedDetailsUseCase = { execute: vi.fn() };
    mockFlashMessage = { show: vi.fn() };

    await TestBed.configureTestingModule({
      imports: [
        CropStagesComponent,
        TranslateModule.forRoot({
          fallbackLang: 'en'
        })
      ],
      providers: [
        CropStagesPresenter,
        { provide: ActivatedRoute, useValue: mockActivatedRoute },
        { provide: LoadCropForEditUseCase, useValue: mockLoadUseCase },
        { provide: CreateCropStageUseCase, useValue: mockCreateCropStageUseCase },
        { provide: ReorderCropStagesUseCase, useValue: mockReorderCropStagesUseCase },
        { provide: DeleteCropStageUseCase, useValue: mockDeleteCropStageUseCase },
        { provide: LoadCropTaskScheduleBlueprintsUseCase, useValue: mockLoadBlueprintsUseCase },
        { provide: UpdateTemperatureRequirementUseCase, useValue: mockUpdateTemperatureRequirementUseCase },
        { provide: SaveCropStagePanelUseCase, useValue: mockSaveCropStagePanelUseCase },
        { provide: SaveCropStageAdvancedDetailsUseCase, useValue: mockSaveCropStageAdvancedDetailsUseCase },
        { provide: FlashMessageService, useValue: mockFlashMessage }
      ]
    })
      .overrideComponent(CropStagesComponent, { set: { providers: [] } })
      .compileComponents();

    TestBed.overrideProvider(LoadCropForEditUseCase, { useValue: mockLoadUseCase });
    TestBed.overrideProvider(CreateCropStageUseCase, { useValue: mockCreateCropStageUseCase });
    TestBed.overrideProvider(ReorderCropStagesUseCase, { useValue: mockReorderCropStagesUseCase });
    TestBed.overrideProvider(DeleteCropStageUseCase, { useValue: mockDeleteCropStageUseCase });
    TestBed.overrideProvider(LoadCropTaskScheduleBlueprintsUseCase, { useValue: mockLoadBlueprintsUseCase });
    TestBed.overrideProvider(UpdateTemperatureRequirementUseCase, { useValue: mockUpdateTemperatureRequirementUseCase });

    fixture = TestBed.createComponent(CropStagesComponent);
    component = fixture.componentInstance;
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

  it('renders stage table with columns and auto-selects first stage', async () => {
    await loadStages([stageFixture]);

    expect(fixture.nativeElement.querySelector('.crop-stages-table')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Order');
    expect(fixture.nativeElement.textContent).toContain('Cumulative GDD');
    expect(component.selectedStageId).toBe(1);
    expect(fixture.nativeElement.querySelector('.crop-stages-edit-panel')).toBeTruthy();
  });

  it('shows em dash for missing table values', async () => {
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

    const row = fixture.nativeElement.querySelector('.crop-stages-table__row');
    expect(row.textContent).toContain('—');
  });

  it('shows cumulative GDD range in table when required_gdd is set', async () => {
    await loadStages([stageFixture]);

    const row = fixture.nativeElement.querySelector('.crop-stages-table__row');
    expect(row.textContent).toContain('0–100');
  });

  it('saves panel fields through SaveCropStagePanelUseCase when save button is clicked', async () => {
    await loadStages([stageFixture]);

    component.stageEditDraft.name = 'Updated Name';
    component.stageEditDraft.base_temperature = 12;
    component.stageEditDraft.optimal_min = 15;
    component.stageEditDraft.optimal_max = 25;
    component.stageEditDraft.max_temperature = 35;
    component.stageEditDraft.required_gdd = 150;
    expect(mockSaveCropStagePanelUseCase.execute).not.toHaveBeenCalled();

    component.saveStagePanel();

    expect(mockSaveCropStagePanelUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1,
      stagePatch: { name: 'Updated Name' },
      temperaturePatch: {
        base_temperature: 12,
        optimal_min: 15,
        optimal_max: 25,
        max_temperature: 35
      },
      thermalPatch: { required_gdd: 150 }
    });
    expect(mockUpdateTemperatureRequirementUseCase.execute).not.toHaveBeenCalled();
  });

  it('opens unsaved confirm when switching stages with dirty panel', async () => {
    await loadStages([
      stageFixture,
      {
        id: 2,
        name: 'Stage 2',
        order: 2,
        temperature_requirement: null,
        thermal_requirement: null,
        sunshine_requirement: null,
        nutrient_requirement: null
      } as CropStage
    ]);

    component.stageEditDraft.name = 'Dirty edit';
    component.selectStage(2);

    expect(HTMLDialogElement.prototype.showModal).toHaveBeenCalled();
    expect(component.pendingStageSwitchId).toBe(2);
    expect(component.selectedStageId).toBe(1);
  });

  it('discards dirty changes and switches stage after unsaved confirm', async () => {
    await loadStages([
      stageFixture,
      {
        id: 2,
        name: 'Stage 2',
        order: 2,
        temperature_requirement: null,
        thermal_requirement: null,
        sunshine_requirement: null,
        nutrient_requirement: null
      } as CropStage
    ]);

    component.stageEditDraft.name = 'Dirty edit';
    component.selectStage(2);
    component.confirmDiscardAndSwitchStage();

    expect(component.selectedStageId).toBe(2);
    expect(component.stageEditDraft.name).toBe('Stage 2');
  });

  it('opens stress threshold dialog and saves only stress fields on explicit save', async () => {
    await loadStages([stageFixture]);

    component.openTemperatureDialog();
    expect(HTMLDialogElement.prototype.showModal).toHaveBeenCalled();
    expect(component.temperatureDetailDraft?.low_stress_threshold).toBeNull();
    expect(component.temperatureDetailDraft).not.toHaveProperty('optimal_min');
    expect(component.temperatureDetailDraft).not.toHaveProperty('max_temperature');

    component.temperatureDetailDraft = {
      low_stress_threshold: 10,
      high_stress_threshold: 30,
      frost_threshold: 0
    };
    component.saveTemperatureDialog();

    expect(mockUpdateTemperatureRequirementUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1,
      payload: {
        low_stress_threshold: 10,
        high_stress_threshold: 30,
        frost_threshold: 0
      }
    });
    expect(HTMLDialogElement.prototype.close).toHaveBeenCalled();
  });

  it('renders inline temperature fields in edit panel', async () => {
    await loadStages([stageFixture]);

    const panel = fixture.nativeElement.querySelector('.crop-stages-edit-panel');
    expect(panel?.querySelector('input[name="panel_optimal_min"]')).toBeTruthy();
    expect(panel?.querySelector('input[name="panel_optimal_max"]')).toBeTruthy();
    expect(panel?.querySelector('input[name="panel_max_temperature"]')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Edit stress thresholds');
  });

  it('marks panel dirty when inline temperature fields change', async () => {
    await loadStages([stageFixture]);

    expect(component.isPanelDirty()).toBe(false);
    component.stageEditDraft.optimal_min = 12;
    expect(component.isPanelDirty()).toBe(true);
  });

  it('opens advanced dialog and saves sunshine, nutrient, and sterility fields through SaveCropStageAdvancedDetailsUseCase', async () => {
    await loadStages([stageFixture]);

    component.openAdvancedDialog();
    component.advancedDetailDraft = {
      minimum_sunshine_hours: 4,
      target_sunshine_hours: 8,
      daily_uptake_n: 0.5,
      daily_uptake_p: 0.2,
      daily_uptake_k: 0.3,
      region: 'jp',
      sterility_risk_threshold: 32
    };
    component.saveAdvancedDialog();

    expect(mockSaveCropStageAdvancedDetailsUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1,
      sunshinePatch: { minimum_sunshine_hours: 4, target_sunshine_hours: 8 },
      nutrientPatch: {
        daily_uptake_n: 0.5,
        daily_uptake_p: 0.2,
        daily_uptake_k: 0.3,
        region: 'jp'
      },
      temperaturePatch: { sterility_risk_threshold: 32 }
    });
    expect(HTMLDialogElement.prototype.close).toHaveBeenCalled();
  });

  it('opens delete confirm dialog from edit panel instead of window.confirm', async () => {
    await loadStages([stageFixture]);

    const deleteButton = fixture.nativeElement.querySelector('.crop-stages-edit-panel .btn-danger');
    deleteButton.click();
    fixture.detectChanges();

    expect(HTMLDialogElement.prototype.showModal).toHaveBeenCalled();
    expect(fixture.nativeElement.querySelector('.crop-stages__delete-confirm')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Delete "Germination"?');
    expect(mockDeleteCropStageUseCase.execute).not.toHaveBeenCalled();
  });

  it('shows blueprint warning when deleting a stage with linked templates', async () => {
    await loadStages([stageFixture]);
    component.control = {
      ...component.control,
      taskScheduleBlueprints: [
        {
          id: 10,
          crop_id: 1,
          agricultural_task_id: 1,
          source_agricultural_task_id: null,
          stage_order: 1,
          stage_name: 'Germination',
          gdd_trigger: 0,
          gdd_tolerance: null,
          task_type: 'general',
          source: 'manual',
          priority: 1,
          amount: null,
          amount_unit: null,
          description: null,
          weather_dependency: null,
          time_per_sqm: null
        }
      ]
    };
    fixture.detectChanges();

    const deleteButton = fixture.nativeElement.querySelector('.crop-stages-edit-panel .btn-danger');
    deleteButton.click();
    fixture.detectChanges();
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain(
      'This stage has 1 linked task schedule template(s).'
    );
  });

  it('calls deleteCropStageUseCase when delete is confirmed in the dialog', async () => {
    await loadStages([stageFixture]);
    component.deleteCropStage(1);
    component.confirmDeleteCropStage();

    expect(mockDeleteCropStageUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1
    });
    expect(HTMLDialogElement.prototype.close).toHaveBeenCalled();
  });

  it('does not call deleteCropStageUseCase when delete confirm is cancelled', async () => {
    await loadStages([stageFixture]);
    component.deleteCropStage(1);
    component.cancelDeleteConfirmDialog();

    expect(mockDeleteCropStageUseCase.execute).not.toHaveBeenCalled();
    expect(HTMLDialogElement.prototype.close).toHaveBeenCalled();
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

  it('shows empty state with description and primary CTA when no stages', async () => {
    await loadStages([]);

    const empty = fixture.nativeElement.querySelector('.crop-stages-empty');
    expect(empty).toBeTruthy();
    expect(empty?.querySelector('.crop-stages-empty__cta')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.crop-stages-table')).toBeNull();
  });

  it('shows add row at table bottom when stages exist', async () => {
    await loadStages([stageFixture]);

    expect(fixture.nativeElement.querySelector('.crop-stages-table__add-row')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.crop-stages-table__add-button')).toBeTruthy();
  });

  it('does not render blueprint readiness checklist or next-step CTA', async () => {
    await loadStages([stageFixture]);

    expect(fixture.nativeElement.querySelector('.blueprint-readiness')).toBeNull();
    expect(fixture.nativeElement.querySelector('.crop-stages__next-step')).toBeNull();
  });

  it('sorts stages by order for display', () => {
    component.control = {
      ...loadedControlBase,
      formData: {
        ...initialFormData,
        name: 'Tomato',
        crop_stages: [
          { id: 2, name: 'Stage 2', order: 2 } as CropStage,
          { id: 1, name: 'Stage 1', order: 1 } as CropStage
        ]
      }
    };

    expect(component.sortedStages.map((stage) => stage.id)).toEqual([1, 2]);
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

  it('shows duplicate order warning', async () => {
    await loadStages([
      { id: 1, name: 'Stage 1', order: 1 } as CropStage,
      { id: 2, name: 'Stage 2', order: 1 } as CropStage
    ]);

    const warning = fixture.nativeElement.querySelector('.crop-stages-order-warning');
    expect(warning?.textContent).toContain('1');
  });

  it('updates cumulative GDD display in table after stage reorder', async () => {
    component.control = {
      ...loadedControlBase,
      formData: {
        ...initialFormData,
        name: 'Tomato',
        crop_stages: [
          {
            id: 1,
            name: 'Stage 1',
            order: 1,
            thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 100 }
          } as CropStage,
          {
            id: 2,
            name: 'Stage 2',
            order: 2,
            thermal_requirement: { id: 2, crop_stage_id: 2, required_gdd: 200 }
          } as CropStage
        ]
      }
    };
    fixture.detectChanges();
    await new Promise<void>((resolve) => queueMicrotask(() => resolve()));

    component.onStageDropped({
      previousIndex: 0,
      currentIndex: 1
    } as CdkDragDrop<CropStage[]>);
    fixture.detectChanges();

    const rows = fixture.nativeElement.querySelectorAll('.crop-stages-table__row');
    expect(rows[0]?.textContent).toContain('0–200');
    expect(rows[1]?.textContent).toContain('200–300');
  });
});
