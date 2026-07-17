import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter, Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, vi } from 'vitest';

import { CropStageEditComponent } from './crop-stage-edit.component';
import { CropStage } from '../../../domain/crops/crop';
import { CropStageEditPresenter } from '../../../usecase/crops/crop-stage-edit.providers';
import { LoadCropForEditUseCase } from '../../../usecase/crops/load-crop-for-edit.usecase';
import { LoadCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/load-crop-task-schedule-blueprints.usecase';
import { DeleteCropStageUseCase } from '../../../usecase/crops/delete-crop-stage.usecase';
import { SaveCropStagePanelUseCase } from '../../../usecase/crops/save-crop-stage-panel.usecase';
import { SaveCropStageAdvancedDetailsUseCase } from '../../../usecase/crops/save-crop-stage-advanced-details.usecase';
import { FlashMessageService } from '../../../services/flash-message.service';
import { AuthService } from '../../../services/auth.service';

const loadedControlBase = {
  loading: false,
  error: null,
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  pendingResyncPanelDraft: false,
  pendingNavigateToList: false,
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

const editTranslations = {
  crops: {
    stage: {
      delete_confirm_message: 'Delete "{{stageName}}"?',
      delete_confirm_blueprint_warning: 'This stage has {{count}} linked task schedule template(s).'
    },
    errors: {
      invalid_id: 'Invalid crop ID.',
      stage_not_found: 'Stage not found.'
    },
    edit: {
      stages_title: 'Growth Stages',
      stages_lead: 'Configure growth stages.',
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
      temperature_section: 'Temperature conditions',
      details_section: 'Advanced settings',
      reference_stages_readonly: 'Reference crops are read-only. Only administrators can edit growth stages.',
      stage_name_required: 'Please enter a stage name.'
    },
    flash: {
      stage_panel_no_changes: 'No changes to save.'
    }
  },
  common: {
    loading: 'Loading...',
    delete: 'Delete',
    cancel: 'Cancel',
    confirm: 'Confirm'
  }
};

describe('CropStageEditComponent', () => {
  let component: CropStageEditComponent;
  let fixture: ComponentFixture<CropStageEditComponent>;
  let mockActivatedRoute: {
    snapshot: {
      paramMap: { get: ReturnType<typeof vi.fn> };
      queryParamMap: { get: ReturnType<typeof vi.fn> };
    };
  };
  let mockRouter: Router;
  let mockLoadUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockLoadBlueprintsUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockDeleteCropStageUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockSaveCropStagePanelUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockSaveCropStageAdvancedDetailsUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockFlashMessage: { show: ReturnType<typeof vi.fn> };
  let mockAuthService: { user: ReturnType<typeof vi.fn> };
  let translateService: TranslateService;

  async function loadStage(
    stage: CropStage = stageFixture,
    options: { is_reference?: boolean; cropName?: string } = {}
  ): Promise<void> {
    const presenter = fixture.debugElement.injector.get(CropStageEditPresenter);
    presenter.setView(component);
    presenter.present({
      crop: {
        id: 1,
        name: options.cropName ?? 'Tomato',
        is_reference: options.is_reference ?? false,
        groups: [],
        crop_stages: [stage]
      }
    });
    presenter.present({ blueprints: [] });
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
          get: vi.fn((key: string) => {
            if (key === 'id') return '1';
            if (key === 'stageId') return '1';
            return null;
          })
        },
        queryParamMap: {
          get: vi.fn(() => null)
        }
      }
    };

    mockLoadUseCase = { execute: vi.fn() };
    mockLoadBlueprintsUseCase = { execute: vi.fn() };
    mockDeleteCropStageUseCase = { execute: vi.fn() };
    mockSaveCropStagePanelUseCase = { execute: vi.fn() };
    mockSaveCropStageAdvancedDetailsUseCase = { execute: vi.fn() };
    mockFlashMessage = { show: vi.fn() };
    mockAuthService = { user: vi.fn(() => ({ admin: false })) };

    await TestBed.configureTestingModule({
      imports: [
        CropStageEditComponent,
        TranslateModule.forRoot({
          fallbackLang: 'en'
        })
      ],
      providers: [
        provideRouter([]),
        CropStageEditPresenter,
        { provide: ActivatedRoute, useValue: mockActivatedRoute },
        { provide: LoadCropForEditUseCase, useValue: mockLoadUseCase },
        { provide: LoadCropTaskScheduleBlueprintsUseCase, useValue: mockLoadBlueprintsUseCase },
        { provide: DeleteCropStageUseCase, useValue: mockDeleteCropStageUseCase },
        { provide: SaveCropStagePanelUseCase, useValue: mockSaveCropStagePanelUseCase },
        { provide: SaveCropStageAdvancedDetailsUseCase, useValue: mockSaveCropStageAdvancedDetailsUseCase },
        { provide: FlashMessageService, useValue: mockFlashMessage },
        { provide: AuthService, useValue: mockAuthService }
      ]
    })
      .overrideComponent(CropStageEditComponent, { set: { providers: [] } })
      .compileComponents();

    TestBed.overrideProvider(LoadCropForEditUseCase, { useValue: mockLoadUseCase });
    TestBed.overrideProvider(LoadCropTaskScheduleBlueprintsUseCase, { useValue: mockLoadBlueprintsUseCase });
    TestBed.overrideProvider(DeleteCropStageUseCase, { useValue: mockDeleteCropStageUseCase });
    TestBed.overrideProvider(SaveCropStagePanelUseCase, { useValue: mockSaveCropStagePanelUseCase });
    TestBed.overrideProvider(SaveCropStageAdvancedDetailsUseCase, {
      useValue: mockSaveCropStageAdvancedDetailsUseCase
    });

    fixture = TestBed.createComponent(CropStageEditComponent);
    component = fixture.componentInstance;
    mockRouter = TestBed.inject(Router);
    vi.spyOn(mockRouter, 'navigate').mockResolvedValue(true);
    translateService = TestBed.inject(TranslateService);
    translateService.setTranslation('en', editTranslations, true);
    translateService.use('en');
  });

  it('loads crop and blueprints on init', () => {
    fixture.detectChanges();
    expect(component.cropId).toBe(1);
    expect(component.stageId).toBe(1);
    expect(mockLoadUseCase.execute).toHaveBeenCalledWith({ cropId: 1 });
    expect(mockLoadBlueprintsUseCase.execute).toHaveBeenCalledWith({ cropId: 1 });
  });

  it('shows info flash and skips save when panel has no changes', async () => {
    await loadStage();

    component.saveStagePanel();

    expect(mockSaveCropStagePanelUseCase.execute).not.toHaveBeenCalled();
    expect(mockFlashMessage.show).toHaveBeenCalledWith({
      type: 'info',
      text: 'crops.flash.stage_panel_no_changes'
    });
  });

  it('disables save button when panel has no unsaved changes', async () => {
    await loadStage();

    const saveButton = fixture.nativeElement.querySelector(
      '.crop-stages-edit-panel__footer .btn-primary'
    ) as HTMLButtonElement;

    expect(saveButton.disabled).toBe(true);
  });

  it('enables save button when panel is dirty', async () => {
    await loadStage();

    component.stageEditDraft.name = 'Updated Name';

    expect(component.canSaveStagePanel()).toBe(true);
  });

  it('saves panel fields through SaveCropStagePanelUseCase when save button is clicked', async () => {
    await loadStage();

    component.stageEditDraft.name = 'Updated Name';
    component.stageEditDraft.base_temperature = 12;
    component.stageEditDraft.optimal_min = 15;
    component.stageEditDraft.optimal_max = 25;
    component.stageEditDraft.max_temperature = 35;
    component.stageEditDraft.required_gdd = 150;

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
  });

  it('navigates to stages list after successful panel save', async () => {
    await loadStage();

    component.stageEditDraft.name = 'Updated Name';
    component.saveStagePanel();

    const presenter = fixture.debugElement.injector.get(CropStageEditPresenter);
    presenter.onSuccess({
      stage: { ...stageFixture, name: 'Updated Name' }
    });
    await new Promise<void>((resolve) => queueMicrotask(() => resolve()));

    expect(mockRouter.navigate).toHaveBeenCalledWith(['/crops', 1, 'stages'], {
      queryParams: undefined
    });
  });

  it('resyncs panel draft from server after partial panel save failure', async () => {
    await loadStage();

    component.stageEditDraft.name = 'Dirty Name';
    component.stageEditDraft.base_temperature = 99;
    expect(component.isPanelDirty()).toBe(true);

    const serverStage: CropStage = {
      ...stageFixture,
      name: 'Server Name',
      temperature_requirement: {
        ...stageFixture.temperature_requirement!,
        base_temperature: 10
      }
    };

    component.control = {
      ...loadedControlBase,
      formData: {
        name: 'Tomato',
        is_reference: false,
        crop_stages: [serverStage]
      },
      pendingResyncPanelDraft: true,
      pendingErrorFlash: { type: 'error', text: 'crops.flash.stage_panel_partial_save_failed' }
    };
    await new Promise<void>((resolve) => queueMicrotask(() => resolve()));
    fixture.detectChanges();

    expect(component.isPanelDirty()).toBe(false);
    expect(component.stageEditDraft).toEqual({
      name: 'Server Name',
      base_temperature: 10,
      optimal_min: null,
      optimal_max: null,
      max_temperature: null,
      required_gdd: 100
    });
  });

  it('opens stress threshold dialog and saves only stress fields on explicit save', async () => {
    await loadStage();

    component.openTemperatureDialog();
    expect(HTMLDialogElement.prototype.showModal).toHaveBeenCalled();
    expect(component.temperatureDetailDraft?.low_stress_threshold).toBeNull();

    component.temperatureDetailDraft = {
      low_stress_threshold: 10,
      high_stress_threshold: 30,
      frost_threshold: 0
    };
    mockSaveCropStagePanelUseCase.execute.mockImplementation(() => {
      const presenter = fixture.debugElement.injector.get(CropStageEditPresenter);
      presenter.onSuccess({
        stage: {
          ...stageFixture,
          temperature_requirement: {
            ...stageFixture.temperature_requirement!,
            low_stress_threshold: 10,
            high_stress_threshold: 30,
            frost_threshold: 0
          }
        }
      });
    });

    component.saveTemperatureDialog();

    expect(mockSaveCropStagePanelUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1,
      temperaturePatch: {
        low_stress_threshold: 10,
        high_stress_threshold: 30,
        frost_threshold: 0
      }
    });
    expect(HTMLDialogElement.prototype.close).toHaveBeenCalled();
    expect(component.temperatureDetailDraft).toBeNull();
  });

  it('keeps temperature dialog open and preserves draft when save API fails', async () => {
    await loadStage();
    const presenter = fixture.debugElement.injector.get(CropStageEditPresenter);

    component.openTemperatureDialog();
    component.temperatureDetailDraft = {
      low_stress_threshold: 10,
      high_stress_threshold: 30,
      frost_threshold: 0
    };
    vi.mocked(HTMLDialogElement.prototype.close).mockClear();

    mockSaveCropStagePanelUseCase.execute.mockImplementation(() => {
      presenter.onError({ message: 'network error' });
    });

    component.saveTemperatureDialog();

    expect(mockSaveCropStagePanelUseCase.execute).toHaveBeenCalled();
    expect(HTMLDialogElement.prototype.close).not.toHaveBeenCalled();
    expect(component.temperatureDetailDraft).toEqual({
      low_stress_threshold: 10,
      high_stress_threshold: 30,
      frost_threshold: 0
    });
  });

  it('opens advanced dialog and saves sunshine, nutrient, and sterility fields', async () => {
    await loadStage();

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
    mockSaveCropStageAdvancedDetailsUseCase.execute.mockImplementation(() => {
      const presenter = fixture.debugElement.injector.get(CropStageEditPresenter);
      presenter.onSuccess({
        stage: {
          ...stageFixture,
          sunshine_requirement: {
            id: 1,
            crop_stage_id: 1,
            minimum_sunshine_hours: 4,
            target_sunshine_hours: 8
          },
          nutrient_requirement: {
            id: 1,
            crop_stage_id: 1,
            daily_uptake_n: 0.5,
            daily_uptake_p: 0.2,
            daily_uptake_k: 0.3,
            region: 'jp'
          },
          temperature_requirement: {
            ...stageFixture.temperature_requirement!,
            sterility_risk_threshold: 32
          }
        }
      });
    });

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
    expect(component.advancedDetailDraft).toBeNull();
  });

  it('opens delete confirm dialog from edit panel instead of window.confirm', async () => {
    await loadStage();

    const deleteButton = fixture.nativeElement.querySelector('.crop-stages-edit-panel .btn-danger');
    deleteButton.click();
    fixture.detectChanges();

    expect(HTMLDialogElement.prototype.showModal).toHaveBeenCalled();
    expect(fixture.nativeElement.querySelector('.crop-stages__delete-confirm')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Delete "Germination"?');
    expect(mockDeleteCropStageUseCase.execute).not.toHaveBeenCalled();
  });

  it('shows blueprint warning when deleting a stage with linked templates', async () => {
    await loadStage();
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

    expect(fixture.nativeElement.textContent).toContain(
      'This stage has 1 linked task schedule template(s).'
    );
  });

  it('calls deleteCropStageUseCase when delete is confirmed in the dialog', async () => {
    await loadStage();
    component.deleteCropStage(1);
    component.confirmDeleteCropStage();

    expect(mockDeleteCropStageUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1
    });
    expect(HTMLDialogElement.prototype.close).toHaveBeenCalled();
  });

  it('does not call deleteCropStageUseCase when delete confirm is cancelled', async () => {
    await loadStage();
    component.deleteCropStage(1);
    component.cancelDeleteConfirmDialog();

    expect(mockDeleteCropStageUseCase.execute).not.toHaveBeenCalled();
    expect(HTMLDialogElement.prototype.close).toHaveBeenCalled();
  });

  it('reports hasUnsavedChanges when panel is dirty', async () => {
    await loadStage();

    expect(component.hasUnsavedChanges()).toBe(false);
    component.stageEditDraft.name = 'Dirty edit';
    expect(component.hasUnsavedChanges()).toBe(true);
  });

  it('confirmDiscardUnsavedChanges opens unsaved confirm dialog and resolves true on confirm', async () => {
    await loadStage();
    component.stageEditDraft.name = 'Dirty edit';

    const promise = component.confirmDiscardUnsavedChanges();
    expect(HTMLDialogElement.prototype.showModal).toHaveBeenCalled();

    component.confirmDiscardUnsavedLeave();
    await expect(promise).resolves.toBe(true);
  });

  it('confirmDiscardUnsavedChanges resolves false when cancelled', async () => {
    await loadStage();
    component.stageEditDraft.name = 'Dirty edit';

    const promise = component.confirmDiscardUnsavedChanges();
    component.cancelUnsavedConfirmDialog();
    await expect(promise).resolves.toBe(false);
  });

  it('disables save when stage name is empty and blocks saveStagePanel', async () => {
    await loadStage();

    component.stageEditDraft.name = '   ';

    expect(component.canSaveStagePanel()).toBe(false);

    component.saveStagePanel();
    expect(mockSaveCropStagePanelUseCase.execute).not.toHaveBeenCalled();
    expect(component.showStageNameError()).toBe(true);
  });

  it('hides mutation controls for reference crops when user is not admin', async () => {
    await loadStage(stageFixture, { is_reference: true, cropName: 'Reference Tomato' });

    expect(fixture.nativeElement.querySelector('.crop-stages__readonly-notice')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('input[name="panel_stage_name"]')?.hasAttribute('readonly')).toBe(
      true
    );
    expect(fixture.nativeElement.querySelector('.crop-stages-edit-panel__footer .btn-primary')).toBeNull();
    expect(fixture.nativeElement.querySelector('.crop-stages-edit-panel__footer .btn-danger')).toBeNull();
  });
});
