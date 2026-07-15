import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, vi } from 'vitest';

import { CropStagesComponent } from './crop-stages.component';
import { CropStage } from '../../../domain/crops/crop';
import { CropStagesPresenter } from '../../../usecase/crops/crop-stages.providers';
import { LoadCropForEditUseCase } from '../../../usecase/crops/load-crop-for-edit.usecase';
import { CreateCropStageUseCase } from '../../../usecase/crops/create-crop-stage.usecase';
import { UpdateCropStageUseCase } from '../../../usecase/crops/update-crop-stage.usecase';
import { DeleteCropStageUseCase } from '../../../usecase/crops/delete-crop-stage.usecase';
import { UpdateTemperatureRequirementUseCase } from '../../../usecase/crops/update-temperature-requirement.usecase';
import { UpdateThermalRequirementUseCase } from '../../../usecase/crops/update-thermal-requirement.usecase';
import { UpdateSunshineRequirementUseCase } from '../../../usecase/crops/update-sunshine-requirement.usecase';
import { UpdateNutrientRequirementUseCase } from '../../../usecase/crops/update-nutrient-requirement.usecase';
import { FlashMessageService } from '../../../services/flash-message.service';
import { CdkDragDrop } from '@angular/cdk/drag-drop';

const initialFormData = {
  name: '',
  crop_stages: [] as CropStage[]
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
  let mockUpdateCropStageUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockDeleteCropStageUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockUpdateTemperatureRequirementUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockUpdateThermalRequirementUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockUpdateSunshineRequirementUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockUpdateNutrientRequirementUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockFlashMessage: { show: ReturnType<typeof vi.fn> };
  let translateService: TranslateService;

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
    mockUpdateCropStageUseCase = { execute: vi.fn() };
    mockDeleteCropStageUseCase = { execute: vi.fn() };
    mockUpdateTemperatureRequirementUseCase = { execute: vi.fn() };
    mockUpdateThermalRequirementUseCase = { execute: vi.fn() };
    mockUpdateSunshineRequirementUseCase = { execute: vi.fn() };
    mockUpdateNutrientRequirementUseCase = { execute: vi.fn() };
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
        { provide: UpdateCropStageUseCase, useValue: mockUpdateCropStageUseCase },
        { provide: DeleteCropStageUseCase, useValue: mockDeleteCropStageUseCase },
        { provide: UpdateTemperatureRequirementUseCase, useValue: mockUpdateTemperatureRequirementUseCase },
        { provide: UpdateThermalRequirementUseCase, useValue: mockUpdateThermalRequirementUseCase },
        { provide: UpdateSunshineRequirementUseCase, useValue: mockUpdateSunshineRequirementUseCase },
        { provide: UpdateNutrientRequirementUseCase, useValue: mockUpdateNutrientRequirementUseCase },
        { provide: FlashMessageService, useValue: mockFlashMessage }
      ]
    }).compileComponents();

    TestBed.overrideProvider(LoadCropForEditUseCase, { useValue: mockLoadUseCase });
    TestBed.overrideProvider(CreateCropStageUseCase, { useValue: mockCreateCropStageUseCase });
    TestBed.overrideProvider(UpdateCropStageUseCase, { useValue: mockUpdateCropStageUseCase });
    TestBed.overrideProvider(DeleteCropStageUseCase, { useValue: mockDeleteCropStageUseCase });
    TestBed.overrideProvider(UpdateTemperatureRequirementUseCase, { useValue: mockUpdateTemperatureRequirementUseCase });
    TestBed.overrideProvider(UpdateThermalRequirementUseCase, { useValue: mockUpdateThermalRequirementUseCase });
    TestBed.overrideProvider(UpdateSunshineRequirementUseCase, { useValue: mockUpdateSunshineRequirementUseCase });
    TestBed.overrideProvider(UpdateNutrientRequirementUseCase, { useValue: mockUpdateNutrientRequirementUseCase });

    fixture = TestBed.createComponent(CropStagesComponent);
    component = fixture.componentInstance;

    translateService = TestBed.inject(TranslateService);
    translateService.setTranslation('ja', {
      crops: {
        stage: {
          default_name: 'Stage 1'
        },
        edit: {
          stage_title: 'ステージ {{order}}'
        }
      }
    }, true);
    translateService.use('ja');
  });

  it('should load crop on init', () => {
    expect(component.cropId).toBe(1);
    fixture.detectChanges();
    expect(mockLoadUseCase.execute).toHaveBeenCalledWith({ cropId: 1 });
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

  it('should call updateCropStageUseCase when updateCropStage is called', () => {
    component.updateCropStage(1, { name: 'New Name' });
    expect(mockUpdateCropStageUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1,
      payload: { name: 'New Name' }
    });
  });

  it('should call deleteCropStageUseCase when deleteCropStage is called with confirmation', () => {
    vi.spyOn(window, 'confirm').mockReturnValue(true);
    component.deleteCropStage(1);
    expect(mockDeleteCropStageUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1
    });
  });

  it('should not call deleteCropStageUseCase when deleteCropStage is cancelled', () => {
    vi.spyOn(window, 'confirm').mockReturnValue(false);
    component.deleteCropStage(1);
    expect(mockDeleteCropStageUseCase.execute).not.toHaveBeenCalled();
  });

  it('should call updateTemperatureRequirementUseCase when updateTemperatureRequirement is called', () => {
    component.updateTemperatureRequirement(1, { base_temperature: 10 });
    expect(mockUpdateTemperatureRequirementUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1,
      payload: { base_temperature: 10 }
    });
  });

  it('should call updateThermalRequirementUseCase when updateThermalRequirement is called', () => {
    component.updateThermalRequirement(1, { required_gdd: 100 });
    expect(mockUpdateThermalRequirementUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1,
      payload: { required_gdd: 100 }
    });
  });

  it('should call updateSunshineRequirementUseCase when updateSunshineRequirement is called', () => {
    component.updateSunshineRequirement(1, { minimum_sunshine_hours: 4 });
    expect(mockUpdateSunshineRequirementUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1,
      payload: { minimum_sunshine_hours: 4 }
    });
  });

  it('should call updateNutrientRequirementUseCase when updateNutrientRequirement is called', () => {
    component.updateNutrientRequirement(1, { daily_uptake_n: 0.5 });
    expect(mockUpdateNutrientRequirementUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1,
      payload: { daily_uptake_n: 0.5 }
    });
  });

  it('should render crop stages without ngModel error after fix', () => {
    component.control = {
      loading: false,
      error: null,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      formData: {
        ...initialFormData,
        name: 'Tomato',
        crop_stages: [
          {
            id: 1,
            name: 'Stage 1',
            order: 1,
            temperature_requirement: null,
            thermal_requirement: null,
            sunshine_requirement: null,
            nutrient_requirement: null
          } as CropStage
        ]
      }
    };

    expect(() => {
      fixture.detectChanges();
    }).not.toThrow();
  });

  it('should translate stage title with correct parameters', () => {
    component.control = {
      loading: false,
      error: null,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      formData: {
        ...initialFormData,
        name: 'Tomato',
        crop_stages: [
          {
            id: 1,
            name: 'Stage 1',
            order: 1,
            temperature_requirement: null,
            thermal_requirement: null,
            sunshine_requirement: null,
            nutrient_requirement: null
          } as CropStage
        ]
      }
    };

    fixture.detectChanges();

    const stageTitleElement = fixture.nativeElement.querySelector('.crop-stage-card__title');
    expect(stageTitleElement).toBeTruthy();
    expect(stageTitleElement.textContent).toContain('ステージ 1');
  });

  it('should link back to crop detail via breadcrumbs', () => {
    component.control = {
      loading: false,
      error: null,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      formData: {
        ...initialFormData,
        name: 'Tomato'
      }
    };

    fixture.detectChanges();

    const pageMain = fixture.nativeElement.querySelector('.page-main');
    const breadcrumb = pageMain?.querySelector(':scope > app-master-context-header');
    const pageHeader = pageMain?.querySelector(':scope > .page-header');
    expect(breadcrumb).toBeTruthy();
    expect(pageHeader).toBeTruthy();
    expect(pageHeader?.querySelector('app-master-context-header')).toBeNull();

    const backLink = breadcrumb?.querySelector(
      'a.master-context-header__back'
    ) as HTMLAnchorElement;
    expect(backLink?.getAttribute('href')).toBe('/crops');

    const cropDetailLink = breadcrumb?.querySelector(
      'a.master-context-header__link'
    ) as HTMLAnchorElement;
    expect(cropDetailLink?.getAttribute('href')).toBe('/crops/1');
    expect(cropDetailLink?.textContent?.trim()).toBe('Tomato');

    expect(breadcrumb?.querySelector('[aria-current="page"]')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.crop-stages__back-link')).toBeNull();
    expect(fixture.nativeElement.querySelector('.crop-stages__return-to-plan')).toBeNull();
  });

  it('shows return-to-plan link when fromPlan query param is set', () => {
    mockActivatedRoute.snapshot.queryParamMap.get.mockImplementation((key: string) =>
      key === 'fromPlan' ? '7' : null
    );
    component.fromPlanId = 7;
    component.control = {
      loading: false,
      error: null,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      formData: {
        ...initialFormData,
        name: 'Tomato'
      }
    };

    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('a[href*="/plans/7"]')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.crop-stages__return-to-plan')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.crop-blueprints__plan-wizard-banner')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('app-master-context-header')).toBeTruthy();
  });

  const stageWithRequirements: CropStage = {
    id: 1,
    name: 'Stage 1',
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

  const loadedControl = {
    loading: false,
    error: null,
    pendingErrorFlash: null,
    pendingSuccessFlash: null,
    formData: {
      ...initialFormData,
      name: 'Tomato',
      crop_stages: [stageWithRequirements]
    }
  };

  it('does not save requirement fields on ngModelChange while typing', () => {
    component.control = loadedControl;
    fixture.detectChanges();

    component.onTemperatureFieldDraft(1, 'base_temperature', 12);
    component.onThermalFieldDraft(1, 'required_gdd', 120);

    expect(mockUpdateTemperatureRequirementUseCase.execute).not.toHaveBeenCalled();
    expect(mockUpdateThermalRequirementUseCase.execute).not.toHaveBeenCalled();
    expect(component.control.formData.crop_stages[0].temperature_requirement?.base_temperature).toBe(12);
    expect(component.control.formData.crop_stages[0].thermal_requirement?.required_gdd).toBe(120);
  });

  it('saves requirement fields on blur after draft edits', () => {
    component.control = loadedControl;
    fixture.detectChanges();

    component.onTemperatureFieldDraft(1, 'base_temperature', 15);
    component.saveTemperatureField(1, 'base_temperature');
    expect(mockUpdateTemperatureRequirementUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1,
      payload: { base_temperature: 15 }
    });

    component.onThermalFieldDraft(1, 'required_gdd', 150);
    component.saveThermalField(1, 'required_gdd');
    expect(mockUpdateThermalRequirementUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1,
      payload: { required_gdd: 150 }
    });
  });

  it('saves sunshine and nutrient requirement fields on blur after draft edits', () => {
    const stageWithSunshineNutrient: CropStage = {
      ...stageWithRequirements,
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
      }
    } as CropStage;

    component.control = {
      ...loadedControl,
      formData: {
        ...loadedControl.formData,
        crop_stages: [stageWithSunshineNutrient]
      }
    };
    fixture.detectChanges();

    component.onSunshineFieldDraft(1, 'minimum_sunshine_hours', 5);
    component.onNutrientFieldDraft(1, 'daily_uptake_n', 0.6);
    expect(mockUpdateSunshineRequirementUseCase.execute).not.toHaveBeenCalled();
    expect(mockUpdateNutrientRequirementUseCase.execute).not.toHaveBeenCalled();

    component.saveSunshineField(1, 'minimum_sunshine_hours');
    expect(mockUpdateSunshineRequirementUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1,
      payload: { minimum_sunshine_hours: 5 }
    });

    component.saveNutrientField(1, 'daily_uptake_n');
    expect(mockUpdateNutrientRequirementUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1,
      payload: { daily_uptake_n: 0.6 }
    });
  });

  it('shows empty state with description and primary CTA when no stages', () => {
    translateService.setTranslation(
      'ja',
      {
        crops: {
          show: {
            no_stages_description: 'この作物の生育ステージを追加してください。'
          },
          edit: {
            stages_title: '生育ステージ',
            stages_lead: 'リード文',
            stages_list_heading: 'ステージ一覧',
            add_stage: 'ステージ追加',
            stages_empty_lead: '生育ステージは栽培テンプレートや作業スケジュールの設定に必要です。'
          }
        }
      },
      true
    );
    translateService.use('ja');

    component.control = {
      loading: false,
      error: null,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      formData: {
        ...initialFormData,
        name: 'Tomato',
        crop_stages: []
      }
    };

    fixture.detectChanges();

    const empty = fixture.nativeElement.querySelector('.crop-stages-empty');
    expect(empty).toBeTruthy();
    expect(empty?.querySelector('.crop-stages-empty__lead')?.textContent?.trim()).toContain(
      '栽培テンプレート'
    );
    expect(empty?.querySelector('.crop-stages-empty__description')?.textContent?.trim()).toContain(
      '生育ステージを追加'
    );

    const cta = empty?.querySelector('.crop-stages-empty__cta') as HTMLButtonElement;
    expect(cta).toBeTruthy();
    expect(cta.classList.contains('btn-primary')).toBe(true);
    expect(cta.textContent?.trim()).toBe('ステージ追加');
    expect(fixture.nativeElement.querySelector('.crop-stages-section__actions button')).toBeNull();
  });

  it('shows stages lead in page description without repeating stages_title in section heading', () => {
    const stagesTitle = '生育ステージ';
    const stagesLead =
      '栽培計画の期間見積もりと作業スケジュール生成に使う、生育ステージと各ステージの環境要件を設定します。';
    const stagesListHeading = 'ステージ一覧';

    translateService.setTranslation(
      'ja',
      {
        crops: {
          stage: {
            default_name: 'Stage 1'
          },
          edit: {
            stages_title: stagesTitle,
            stages_lead: stagesLead,
            stages_list_heading: stagesListHeading,
            stage_title: 'ステージ {{order}}',
            add_stage: 'ステージ追加'
          }
        },
        common: {
          back: '戻る'
        }
      },
      true
    );
    translateService.use('ja');

    component.control = {
      loading: false,
      error: null,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      formData: {
        ...initialFormData,
        name: 'トマト',
        crop_stages: []
      }
    };

    fixture.detectChanges();

    const pageDescription = fixture.nativeElement.querySelector('.page-description');
    expect(pageDescription?.textContent?.trim()).toBe(stagesLead);

    const sectionHeading = fixture.nativeElement.querySelector('#stages-heading');
    expect(sectionHeading?.textContent?.trim()).toBe(stagesListHeading);
    expect(sectionHeading?.textContent?.trim()).not.toBe(stagesTitle);
  });

  it('uses h3 for requirement subsection titles instead of h4', () => {
    translateService.setTranslation(
      'ja',
      {
        crops: {
          stage: {
            default_name: 'Stage 1'
          },
          edit: {
            stages_title: '生育ステージ',
            stages_lead: 'リード文',
            stages_list_heading: 'ステージ一覧',
            stage_title: 'ステージ {{order}}',
            requirements_title: '要件',
            temperature_requirement: '温度要件',
            thermal_requirement: '積算温度要件',
            sunshine_requirement: '日照要件',
            nutrient_requirement: '栄養素要件',
            add_stage: 'ステージ追加'
          }
        },
        common: {
          back: '戻る',
          delete: '削除'
        }
      },
      true
    );
    translateService.use('ja');

    component.control = {
      loading: false,
      error: null,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      formData: {
        ...initialFormData,
        name: 'トマト',
        crop_stages: [
          {
            id: 1,
            name: 'Stage 1',
            order: 1,
            temperature_requirement: null,
            thermal_requirement: null,
            sunshine_requirement: null,
            nutrient_requirement: null
          } as CropStage
        ]
      }
    };

    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.requirement-section__title')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('h4.requirement-section__title')).toBeNull();
    expect(fixture.nativeElement.querySelector('h3.requirement-section__title')).toBeTruthy();
  });

  it('shows cumulative GDD range when stage has required_gdd', () => {
    translateService.setTranslation(
      'ja',
      {
        crops: {
          stage: {
            default_name: 'Stage 1'
          },
          edit: {
            stage_title: 'ステージ {{order}}',
            stages_title: '生育ステージ',
            stage_name: 'ステージ名',
            stage_order: '順序',
            requirements_title: '要件',
            temperature_requirement: '温度',
            thermal_requirement: '積算温度',
            required_gdd: '必要GDD',
            sunshine_requirement: '日照',
            nutrient_requirement: '栄養',
            stage_cumulative_gdd_range: '{{start}}〜{{end}} ℃·日（累積）',
            stage_cumulative_gdd_missing: '必要積算温度を入力すると表示されます'
          }
        },
        common: {
          back: '戻る',
          delete: '削除'
        }
      },
      true
    );
    translateService.use('ja');

    component.control = {
      loading: false,
      error: null,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      formData: {
        ...initialFormData,
        name: 'Tomato',
        crop_stages: [
          {
            id: 1,
            name: 'Stage 1',
            order: 1,
            temperature_requirement: null,
            thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 200 },
            sunshine_requirement: null,
            nutrient_requirement: null
          } as CropStage
        ]
      }
    };

    fixture.detectChanges();

    const cumulativeGdd = fixture.nativeElement.querySelector('.crop-stage-cumulative-gdd');
    expect(cumulativeGdd).toBeTruthy();
    expect(cumulativeGdd.textContent).toContain('0〜200');
  });

  it('sorts stages by order for display', () => {
    component.control = {
      loading: false,
      error: null,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      formData: {
        ...initialFormData,
        name: 'Tomato',
        crop_stages: [
          {
            id: 2,
            name: 'Stage 2',
            order: 2,
            temperature_requirement: null,
            thermal_requirement: null,
            sunshine_requirement: null,
            nutrient_requirement: null
          } as CropStage,
          {
            id: 1,
            name: 'Stage 1',
            order: 1,
            temperature_requirement: null,
            thermal_requirement: null,
            sunshine_requirement: null,
            nutrient_requirement: null
          } as CropStage
        ]
      }
    };

    expect(component.sortedStages.map((stage) => stage.id)).toEqual([1, 2]);
  });

  it('persists reordered stage orders after drag-drop', () => {
    component.control = {
      loading: false,
      error: null,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      formData: {
        ...initialFormData,
        name: 'Tomato',
        crop_stages: [
          {
            id: 1,
            name: 'Stage 1',
            order: 1,
            temperature_requirement: null,
            thermal_requirement: null,
            sunshine_requirement: null,
            nutrient_requirement: null
          } as CropStage,
          {
            id: 2,
            name: 'Stage 2',
            order: 2,
            temperature_requirement: null,
            thermal_requirement: null,
            sunshine_requirement: null,
            nutrient_requirement: null
          } as CropStage,
          {
            id: 3,
            name: 'Stage 3',
            order: 3,
            temperature_requirement: null,
            thermal_requirement: null,
            sunshine_requirement: null,
            nutrient_requirement: null
          } as CropStage
        ]
      }
    };

    component.onStageDropped({
      previousIndex: 0,
      currentIndex: 2
    } as CdkDragDrop<CropStage[]>);

    expect(component.control.formData.crop_stages.map((stage) => stage.order)).toEqual([1, 2, 3]);
    expect(mockUpdateCropStageUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 1,
      payload: { order: 3 }
    });
    expect(mockUpdateCropStageUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 2,
      payload: { order: 1 }
    });
    expect(mockUpdateCropStageUseCase.execute).toHaveBeenCalledWith({
      cropId: 1,
      stageId: 3,
      payload: { order: 2 }
    });
  });

  it('shows duplicate order warning and blocks save on blur', () => {
    translateService.setTranslation(
      'ja',
      {
        crops: {
          edit: {
            stage_order_duplicate: '順序 {{orders}} が重複しています'
          }
        }
      },
      true
    );
    translateService.use('ja');

    const duplicateStage = {
      id: 2,
      name: 'Stage 2',
      order: 1,
      temperature_requirement: null,
      thermal_requirement: null,
      sunshine_requirement: null,
      nutrient_requirement: null
    } as CropStage;

    component.control = {
      loading: false,
      error: null,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      formData: {
        ...initialFormData,
        name: 'Tomato',
        crop_stages: [
          {
            id: 1,
            name: 'Stage 1',
            order: 1,
            temperature_requirement: null,
            thermal_requirement: null,
            sunshine_requirement: null,
            nutrient_requirement: null
          } as CropStage,
          duplicateStage
        ]
      }
    };

    fixture.detectChanges();

    const warning = fixture.nativeElement.querySelector('.crop-stages-order-warning');
    expect(warning?.textContent).toContain('1');

    component.onStageOrderBlur(duplicateStage);

    expect(mockFlashMessage.show).toHaveBeenCalledWith({
      type: 'error',
      text: '順序 1 が重複しています'
    });
    expect(mockUpdateCropStageUseCase.execute).not.toHaveBeenCalled();
  });

  it('updates cumulative GDD display after stage reorder', () => {
    translateService.setTranslation(
      'ja',
      {
        crops: {
          edit: {
            stage_title: 'ステージ {{order}}',
            stage_cumulative_gdd_range: '{{start}}〜{{end}} ℃·日（累積）'
          }
        }
      },
      true
    );
    translateService.use('ja');

    component.control = {
      loading: false,
      error: null,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      formData: {
        ...initialFormData,
        name: 'Tomato',
        crop_stages: [
          {
            id: 1,
            name: 'Stage 1',
            order: 1,
            temperature_requirement: null,
            thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 100 },
            sunshine_requirement: null,
            nutrient_requirement: null
          } as CropStage,
          {
            id: 2,
            name: 'Stage 2',
            order: 2,
            temperature_requirement: null,
            thermal_requirement: { id: 2, crop_stage_id: 2, required_gdd: 200 },
            sunshine_requirement: null,
            nutrient_requirement: null
          } as CropStage
        ]
      }
    };

    fixture.detectChanges();

    component.onStageDropped({
      previousIndex: 0,
      currentIndex: 1
    } as CdkDragDrop<CropStage[]>);
    fixture.detectChanges();

    const cumulativeGddElements = fixture.nativeElement.querySelectorAll('.crop-stage-cumulative-gdd');
    expect(cumulativeGddElements[0]?.textContent).toContain('0〜200');
    expect(cumulativeGddElements[1]?.textContent).toContain('200〜300');
  });
});
