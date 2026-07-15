import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { CdkDragDrop, DragDropModule } from '@angular/cdk/drag-drop';
import { CropStagesView, CropStagesViewState, CropStagesFormData } from './crop-stages.view';
import { LoadCropForEditUseCase } from '../../../usecase/crops/load-crop-for-edit.usecase';
import { CreateCropStageUseCase } from '../../../usecase/crops/create-crop-stage.usecase';
import { UpdateCropStageUseCase } from '../../../usecase/crops/update-crop-stage.usecase';
import { DeleteCropStageUseCase } from '../../../usecase/crops/delete-crop-stage.usecase';
import { UpdateTemperatureRequirementUseCase } from '../../../usecase/crops/update-temperature-requirement.usecase';
import { UpdateThermalRequirementUseCase } from '../../../usecase/crops/update-thermal-requirement.usecase';
import { UpdateSunshineRequirementUseCase } from '../../../usecase/crops/update-sunshine-requirement.usecase';
import { UpdateNutrientRequirementUseCase } from '../../../usecase/crops/update-nutrient-requirement.usecase';
import {
  CropStagesPresenter,
  CROP_STAGES_PROVIDERS
} from '../../../usecase/crops/crop-stages.providers';
import { FlashMessageService } from '../../../services/flash-message.service';
import { applyPendingFlashViewEffects } from '../../../core/view-effects/pending-success-flash-view.effects';
import { parseFromPlanId } from '../../../domain/crops/parse-from-plan-id';
import {
  parsePlanWizardReturnTab,
  planWizardReturnPath,
  type PlanWizardReturnTab
} from '../../../domain/crops/plan-wizard-context';
import { stageCumulativeGddRange } from '../../../domain/crops/stage-cumulative-gdd';
import {
  stageMissingBaseTemperature,
  stageMissingRequiredGdd,
  stageRequirementsComplete
} from '../../../domain/crops/blueprint-generation-readiness';
import {
  findDuplicateStageOrders,
  reorderStagesByIndex,
  sortStagesByOrder
} from '../../../domain/crops/crop-stage-order';
import type { CropStage } from '../../../domain/crops/crop';
import { MasterContextHeaderComponent } from '../master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../master-context-header/master-context-crumb';

const initialFormData: CropStagesFormData = {
  name: '',
  crop_stages: []
};

const initialControl: CropStagesViewState = {
  loading: true,
  error: null,
  formData: initialFormData,
  pendingErrorFlash: null,
  pendingSuccessFlash: null
};

@Component({
  selector: 'app-crop-stages',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, TranslateModule, MasterContextHeaderComponent, DragDropModule],
  providers: [...CROP_STAGES_PROVIDERS],
  template: `
    <main class="page-main">
      @if (control.loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (control.error) {
        <p class="master-loading master-error">{{ control.error }}</p>
      } @else {
        <app-master-context-header [crumbs]="contextCrumbs" />
        @if (fromPlanId) {
          <div class="crop-blueprints__plan-wizard-banner" role="status">
            <p class="crop-blueprints__plan-wizard-banner-title">
              {{ 'crops.show.from_plan_wizard_title' | translate }}
            </p>
            <p class="crop-blueprints__plan-wizard-banner-lead">
              {{ 'crops.show.from_plan_stages_wizard_lead' | translate }}
            </p>
            <a [routerLink]="planReturnPath" class="btn-secondary crop-stages__return-to-plan">
              {{ 'crops.show.return_to_plan' | translate }}
            </a>
          </div>
        }

        <header class="page-header crop-stages__page-header">
          <h1 class="page-title">{{ control.formData.name }}</h1>
          <p class="page-description">{{ 'crops.edit.stages_lead' | translate }}</p>
        </header>

        <section class="form-card crop-stages-section" aria-labelledby="stages-heading">
          <h2 id="stages-heading" class="crop-stages-section__title">{{ 'crops.edit.stages_list_heading' | translate }}</h2>
          @if (control.formData.crop_stages.length > 0) {
            <div class="crop-stages-section__actions">
              <button type="button" class="btn btn-secondary" (click)="addCropStage()">
                {{ 'crops.edit.add_stage' | translate }}
              </button>
            </div>
          }
          @if (duplicateStageOrders.length > 0) {
            <p class="crop-stages-order-warning" role="alert">
              {{
                'crops.edit.stage_order_duplicate'
                  | translate: { orders: duplicateStageOrders.join(', ') }
              }}
            </p>
          }
          <div
            class="crop-stages-list"
            cdkDropList
            [cdkDropListData]="sortedStages"
            (cdkDropListDropped)="onStageDropped($event)"
          >
            @if (control.formData.crop_stages.length === 0) {
              <div class="crop-stages-empty">
                <p class="crop-stages-empty__lead">{{ 'crops.edit.stages_empty_lead' | translate }}</p>
                <p class="crop-stages-empty__description">{{ 'crops.show.no_stages_description' | translate }}</p>
                <button type="button" class="btn btn-primary crop-stages-empty__cta" (click)="addCropStage()">
                  {{ 'crops.edit.add_stage' | translate }}
                </button>
              </div>
            } @else {
            @for (stage of sortedStages; track stage.id) {
              <div class="crop-stage-card" cdkDrag [cdkDragData]="stage">
                <div class="crop-stage-card__header">
                  <h3 class="crop-stage-card__title">{{ 'crops.edit.stage_title' | translate:{ order: stage.order } }}</h3>
                  <button type="button" class="btn btn-danger" (click)="deleteCropStage(stage.id)">
                    {{ 'common.delete' | translate }}
                  </button>
                </div>
                <div class="crop-stage-card__content">
                  <label class="form-card__field">
                    <span class="form-card__field-label">{{ 'crops.edit.stage_name' | translate }}</span>
                    <input type="text" name="stage_name_{{ stage.id }}" [(ngModel)]="stage.name" (blur)="updateCropStage(stage.id, { name: stage.name })" />
                  </label>
                  <label class="form-card__field">
                    <span class="form-card__field-label">{{ 'crops.edit.stage_order' | translate }}</span>
                    <input type="number" name="stage_order_{{ stage.id }}" [(ngModel)]="stage.order" (blur)="onStageOrderBlur(stage)" />
                  </label>

                  <details class="crop-stage-requirements" [open]="shouldOpenRequirements(stage)">
                    <summary class="crop-stage-requirements__summary">{{ 'crops.edit.requirements_title' | translate }}</summary>

                    <div class="requirement-section">
                      <h3 class="requirement-section__title">{{ 'crops.edit.temperature_requirement' | translate }}</h3>
                      <div class="requirement-fields">
                        <label class="form-card__field form-card__field--small">
                          <span class="form-card__field-label">
                            {{ 'crops.edit.base_temperature' | translate }}
                            @if (isBaseTemperatureMissing(stage)) {
                              <span class="form-card__field-required-marker">{{ 'crops.edit.required_marker' | translate }}</span>
                            }
                          </span>
                          <input type="number" step="0.1" name="temp_base_{{ stage.id }}" [ngModel]="stage.temperature_requirement?.base_temperature ?? null"
                                 (ngModelChange)="onTemperatureFieldDraft(stage.id, 'base_temperature', $event)"
                                 (blur)="saveTemperatureField(stage.id, 'base_temperature')" />
                        </label>
                        <label class="form-card__field form-card__field--small">
                          <span class="form-card__field-label">{{ 'crops.edit.optimal_min' | translate }}</span>
                          <input type="number" step="0.1" name="temp_opt_min_{{ stage.id }}" [ngModel]="stage.temperature_requirement?.optimal_min ?? null"
                                 (ngModelChange)="onTemperatureFieldDraft(stage.id, 'optimal_min', $event)"
                                 (blur)="saveTemperatureField(stage.id, 'optimal_min')" />
                        </label>
                        <label class="form-card__field form-card__field--small">
                          <span class="form-card__field-label">{{ 'crops.edit.optimal_max' | translate }}</span>
                          <input type="number" step="0.1" name="temp_opt_max_{{ stage.id }}" [ngModel]="stage.temperature_requirement?.optimal_max ?? null"
                                 (ngModelChange)="onTemperatureFieldDraft(stage.id, 'optimal_max', $event)"
                                 (blur)="saveTemperatureField(stage.id, 'optimal_max')" />
                        </label>
                        <label class="form-card__field form-card__field--small">
                          <span class="form-card__field-label">{{ 'crops.edit.low_stress_threshold' | translate }}</span>
                          <input type="number" step="0.1" name="temp_low_stress_{{ stage.id }}" [ngModel]="stage.temperature_requirement?.low_stress_threshold ?? null"
                                 (ngModelChange)="onTemperatureFieldDraft(stage.id, 'low_stress_threshold', $event)"
                                 (blur)="saveTemperatureField(stage.id, 'low_stress_threshold')" />
                        </label>
                        <label class="form-card__field form-card__field--small">
                          <span class="form-card__field-label">{{ 'crops.edit.high_stress_threshold' | translate }}</span>
                          <input type="number" step="0.1" name="temp_high_stress_{{ stage.id }}" [ngModel]="stage.temperature_requirement?.high_stress_threshold ?? null"
                                 (ngModelChange)="onTemperatureFieldDraft(stage.id, 'high_stress_threshold', $event)"
                                 (blur)="saveTemperatureField(stage.id, 'high_stress_threshold')" />
                        </label>
                        <label class="form-card__field form-card__field--small">
                          <span class="form-card__field-label">{{ 'crops.edit.frost_threshold' | translate }}</span>
                          <input type="number" step="0.1" name="temp_frost_{{ stage.id }}" [ngModel]="stage.temperature_requirement?.frost_threshold ?? null"
                                 (ngModelChange)="onTemperatureFieldDraft(stage.id, 'frost_threshold', $event)"
                                 (blur)="saveTemperatureField(stage.id, 'frost_threshold')" />
                        </label>
                        <label class="form-card__field form-card__field--small">
                          <span class="form-card__field-label">{{ 'crops.edit.sterility_risk_threshold' | translate }}</span>
                          <input type="number" step="0.1" name="temp_sterility_{{ stage.id }}" [ngModel]="stage.temperature_requirement?.sterility_risk_threshold ?? null"
                                 (ngModelChange)="onTemperatureFieldDraft(stage.id, 'sterility_risk_threshold', $event)"
                                 (blur)="saveTemperatureField(stage.id, 'sterility_risk_threshold')" />
                        </label>
                        <label class="form-card__field form-card__field--small">
                          <span class="form-card__field-label">{{ 'crops.edit.max_temperature' | translate }}</span>
                          <input type="number" step="0.1" name="temp_max_{{ stage.id }}" [ngModel]="stage.temperature_requirement?.max_temperature ?? null"
                                 (ngModelChange)="onTemperatureFieldDraft(stage.id, 'max_temperature', $event)"
                                 (blur)="saveTemperatureField(stage.id, 'max_temperature')" />
                        </label>
                      </div>
                    </div>

                    <div class="requirement-section">
                      <h3 class="requirement-section__title">{{ 'crops.edit.thermal_requirement' | translate }}</h3>
                      <div class="requirement-fields">
                        <label class="form-card__field form-card__field--small">
                          <span class="form-card__field-label">
                            {{ 'crops.edit.required_gdd' | translate }}
                            @if (isRequiredGddMissing(stage)) {
                              <span class="form-card__field-required-marker">{{ 'crops.edit.required_marker' | translate }}</span>
                            }
                          </span>
                          <input type="number" step="0.1" name="thermal_gdd_{{ stage.id }}" [ngModel]="stage.thermal_requirement?.required_gdd ?? null"
                                 (ngModelChange)="onThermalFieldDraft(stage.id, 'required_gdd', $event)"
                                 (blur)="saveThermalField(stage.id, 'required_gdd')" />
                        </label>
                        <p class="crop-stage-cumulative-gdd" role="status">
                          @if (stageCumulativeGddRangeFor(stage); as range) {
                            @if (range.gddRangeMissing) {
                              {{ 'crops.edit.stage_cumulative_gdd_missing' | translate }}
                            } @else {
                              {{
                                'crops.edit.stage_cumulative_gdd_range'
                                  | translate: {
                                      start: range.cumulativeGddStart,
                                      end: range.cumulativeGddEnd
                                    }
                              }}
                            }
                          }
                        </p>
                      </div>
                    </div>

                    <div class="requirement-section">
                      <h3 class="requirement-section__title">{{ 'crops.edit.sunshine_requirement' | translate }}</h3>
                      <div class="requirement-fields">
                        <label class="form-card__field form-card__field--small">
                          <span class="form-card__field-label">{{ 'crops.edit.minimum_sunshine_hours' | translate }}</span>
                          <input type="number" step="0.1" name="sunshine_min_{{ stage.id }}" [ngModel]="stage.sunshine_requirement?.minimum_sunshine_hours ?? null"
                                 (ngModelChange)="onSunshineFieldDraft(stage.id, 'minimum_sunshine_hours', $event)"
                                 (blur)="saveSunshineField(stage.id, 'minimum_sunshine_hours')" />
                        </label>
                        <label class="form-card__field form-card__field--small">
                          <span class="form-card__field-label">{{ 'crops.edit.target_sunshine_hours' | translate }}</span>
                          <input type="number" step="0.1" name="sunshine_target_{{ stage.id }}" [ngModel]="stage.sunshine_requirement?.target_sunshine_hours ?? null"
                                 (ngModelChange)="onSunshineFieldDraft(stage.id, 'target_sunshine_hours', $event)"
                                 (blur)="saveSunshineField(stage.id, 'target_sunshine_hours')" />
                        </label>
                      </div>
                    </div>

                    <div class="requirement-section">
                      <h3 class="requirement-section__title">{{ 'crops.edit.nutrient_requirement' | translate }}</h3>
                      <div class="requirement-fields">
                        <label class="form-card__field form-card__field--small">
                          <span class="form-card__field-label">{{ 'crops.edit.daily_uptake_n' | translate }}</span>
                          <input type="number" step="0.01" name="nutrient_n_{{ stage.id }}" [ngModel]="stage.nutrient_requirement?.daily_uptake_n ?? null"
                                 (ngModelChange)="onNutrientFieldDraft(stage.id, 'daily_uptake_n', $event)"
                                 (blur)="saveNutrientField(stage.id, 'daily_uptake_n')" />
                        </label>
                        <label class="form-card__field form-card__field--small">
                          <span class="form-card__field-label">{{ 'crops.edit.daily_uptake_p' | translate }}</span>
                          <input type="number" step="0.01" name="nutrient_p_{{ stage.id }}" [ngModel]="stage.nutrient_requirement?.daily_uptake_p ?? null"
                                 (ngModelChange)="onNutrientFieldDraft(stage.id, 'daily_uptake_p', $event)"
                                 (blur)="saveNutrientField(stage.id, 'daily_uptake_p')" />
                        </label>
                        <label class="form-card__field form-card__field--small">
                          <span class="form-card__field-label">{{ 'crops.edit.daily_uptake_k' | translate }}</span>
                          <input type="number" step="0.01" name="nutrient_k_{{ stage.id }}" [ngModel]="stage.nutrient_requirement?.daily_uptake_k ?? null"
                                 (ngModelChange)="onNutrientFieldDraft(stage.id, 'daily_uptake_k', $event)"
                                 (blur)="saveNutrientField(stage.id, 'daily_uptake_k')" />
                        </label>
                        <label class="form-card__field form-card__field--small">
                          <span class="form-card__field-label">{{ 'crops.edit.region' | translate }}</span>
                          <input type="text" name="nutrient_region_{{ stage.id }}" [ngModel]="stage.nutrient_requirement?.region ?? null"
                                 (ngModelChange)="onNutrientFieldDraft(stage.id, 'region', $event)"
                                 (blur)="saveNutrientField(stage.id, 'region')" />
                        </label>
                      </div>
                    </div>
                  </details>
                </div>
              </div>
            }
            }
          </div>
        </section>
      }
    </main>
  `,
  styleUrls: ['./crop-stages.component.css']
})
export class CropStagesComponent implements CropStagesView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly loadUseCase = inject(LoadCropForEditUseCase);
  private readonly createCropStageUseCase = inject(CreateCropStageUseCase);
  private readonly updateCropStageUseCase = inject(UpdateCropStageUseCase);
  private readonly deleteCropStageUseCase = inject(DeleteCropStageUseCase);
  private readonly updateTemperatureRequirementUseCase = inject(UpdateTemperatureRequirementUseCase);
  private readonly updateThermalRequirementUseCase = inject(UpdateThermalRequirementUseCase);
  private readonly updateSunshineRequirementUseCase = inject(UpdateSunshineRequirementUseCase);
  private readonly updateNutrientRequirementUseCase = inject(UpdateNutrientRequirementUseCase);
  private readonly presenter = inject(CropStagesPresenter);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly translate = inject(TranslateService);

  private _control: CropStagesViewState = initialControl;
  get control(): CropStagesViewState {
    return this._control;
  }
  set control(value: CropStagesViewState) {
    this._control = applyPendingFlashViewEffects(value, { flash: this.flashMessage });
    this.cdr.markForCheck();
  }

  get cropId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  fromPlanId: number | null = null;
  returnTab: PlanWizardReturnTab = 'task_schedule';

  get planReturnPath(): (string | number)[] {
    return this.fromPlanId != null ? planWizardReturnPath(this.fromPlanId, this.returnTab) : [];
  }

  get contextCrumbs(): MasterContextCrumb[] {
    const crumbs: MasterContextCrumb[] = [
      { labelKey: 'crops.index.title', routerLink: ['/crops'] }
    ];
    const cropName = this.control.formData.name;
    if (cropName) {
      crumbs.push({ label: cropName, routerLink: ['/crops', this.cropId] });
    }
    crumbs.push({ labelKey: 'crops.edit.stages_title' });
    return crumbs;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.fromPlanId = parseFromPlanId(this.route.snapshot.queryParamMap.get('fromPlan'));
    this.returnTab = parsePlanWizardReturnTab(this.route.snapshot.queryParamMap.get('returnTo'));
    if (!this.cropId) {
      this.control = {
        ...initialControl,
        loading: false,
        error: this.translate.instant('crops.errors.invalid_id')
      };
      return;
    }
    this.loadUseCase.execute({ cropId: this.cropId });
  }

  addCropStage(): void {
    const nextOrder = Math.max(0, ...this.control.formData.crop_stages.map(s => s.order)) + 1;
    const defaultStageName = this.translate.instant('crops.stage.default_name', { order: nextOrder });
    this.createCropStageUseCase.execute({
      cropId: this.cropId,
      payload: {
        name: defaultStageName,
        order: nextOrder
      }
    });
  }

  updateCropStage(stageId: number, payload: { name?: string; order?: number }): void {
    this.updateCropStageUseCase.execute({
      cropId: this.cropId,
      stageId,
      payload
    });
  }

  deleteCropStage(stageId: number): void {
    if (confirm(this.translate.instant('crops.stage.confirm_delete'))) {
      this.deleteCropStageUseCase.execute({
        cropId: this.cropId,
        stageId
      });
    }
  }

  updateTemperatureRequirement(stageId: number, payload: any): void {
    this.updateTemperatureRequirementUseCase.execute({
      cropId: this.cropId,
      stageId,
      payload
    });
  }

  updateThermalRequirement(stageId: number, payload: any): void {
    this.updateThermalRequirementUseCase.execute({
      cropId: this.cropId,
      stageId,
      payload
    });
  }

  updateSunshineRequirement(stageId: number, payload: any): void {
    this.updateSunshineRequirementUseCase.execute({
      cropId: this.cropId,
      stageId,
      payload
    });
  }

  updateNutrientRequirement(stageId: number, payload: any): void {
    this.updateNutrientRequirementUseCase.execute({
      cropId: this.cropId,
      stageId,
      payload
    });
  }

  onTemperatureFieldDraft(stageId: number, field: string, value: number | null): void {
    const stage = this.control.formData.crop_stages.find(s => s.id === stageId);
    if (!stage) return;

    if (!stage.temperature_requirement) {
      stage.temperature_requirement = {
        id: 0,
        crop_stage_id: stageId,
        base_temperature: null,
        optimal_min: null,
        optimal_max: null,
        low_stress_threshold: null,
        high_stress_threshold: null,
        frost_threshold: null,
        sterility_risk_threshold: null,
        max_temperature: null
      };
    }
    (stage.temperature_requirement as any)[field] = value;
  }

  saveTemperatureField(stageId: number, field: string): void {
    const stage = this.control.formData.crop_stages.find(s => s.id === stageId);
    if (!stage?.temperature_requirement) return;

    const value = (stage.temperature_requirement as any)[field];
    this.updateTemperatureRequirement(stageId, { [field]: value });
  }

  onThermalFieldDraft(stageId: number, field: string, value: number | null): void {
    const stage = this.control.formData.crop_stages.find(s => s.id === stageId);
    if (!stage) return;

    if (!stage.thermal_requirement) {
      stage.thermal_requirement = {
        id: 0,
        crop_stage_id: stageId,
        required_gdd: null
      };
    }
    (stage.thermal_requirement as any)[field] = value;
    this.cdr.markForCheck();
  }

  saveThermalField(stageId: number, field: string): void {
    const stage = this.control.formData.crop_stages.find(s => s.id === stageId);
    if (!stage?.thermal_requirement) return;

    const value = (stage.thermal_requirement as any)[field];
    this.updateThermalRequirement(stageId, { [field]: value });
  }

  get sortedStages(): CropStage[] {
    return sortStagesByOrder(this.control.formData.crop_stages);
  }

  get duplicateStageOrders(): number[] {
    return findDuplicateStageOrders(this.control.formData.crop_stages);
  }

  onStageDropped(event: CdkDragDrop<CropStage[]>): void {
    const { stages, updates } = reorderStagesByIndex(
      this.control.formData.crop_stages,
      event.previousIndex,
      event.currentIndex
    );
    if (updates.length === 0) {
      return;
    }

    this.control = {
      ...this.control,
      formData: {
        ...this.control.formData,
        crop_stages: stages
      }
    };

    for (const { id, order } of updates) {
      this.updateCropStageUseCase.execute({
        cropId: this.cropId,
        stageId: id,
        payload: { order }
      });
    }
  }

  onStageOrderBlur(stage: CropStage): void {
    if (this.duplicateStageOrders.length > 0) {
      this.flashMessage.show({
        type: 'error',
        text: this.translate.instant('crops.edit.stage_order_duplicate', {
          orders: this.duplicateStageOrders.join(', ')
        })
      });
      return;
    }

    this.updateCropStage(stage.id, { order: stage.order });
  }

  stageCumulativeGddRangeFor(stage: CropStage) {
    return stageCumulativeGddRange(this.control.formData.crop_stages, stage.order);
  }

  shouldOpenRequirements(stage: CropStage): boolean {
    return this.fromPlanId != null || !stageRequirementsComplete(stage);
  }

  isBaseTemperatureMissing(stage: CropStage): boolean {
    return stageMissingBaseTemperature(stage);
  }

  isRequiredGddMissing(stage: CropStage): boolean {
    return stageMissingRequiredGdd(stage);
  }

  onSunshineFieldDraft(stageId: number, field: string, value: number | null): void {
    const stage = this.control.formData.crop_stages.find(s => s.id === stageId);
    if (!stage) return;

    if (!stage.sunshine_requirement) {
      stage.sunshine_requirement = {
        id: 0,
        crop_stage_id: stageId,
        minimum_sunshine_hours: null,
        target_sunshine_hours: null
      };
    }
    (stage.sunshine_requirement as any)[field] = value;
  }

  saveSunshineField(stageId: number, field: string): void {
    const stage = this.control.formData.crop_stages.find(s => s.id === stageId);
    if (!stage?.sunshine_requirement) return;

    const value = (stage.sunshine_requirement as any)[field];
    this.updateSunshineRequirement(stageId, { [field]: value });
  }

  onNutrientFieldDraft(stageId: number, field: string, value: number | string | null): void {
    const stage = this.control.formData.crop_stages.find(s => s.id === stageId);
    if (!stage) return;

    if (!stage.nutrient_requirement) {
      stage.nutrient_requirement = {
        id: 0,
        crop_stage_id: stageId,
        daily_uptake_n: null,
        daily_uptake_p: null,
        daily_uptake_k: null,
        region: null
      };
    }
    (stage.nutrient_requirement as any)[field] = value;
  }

  saveNutrientField(stageId: number, field: string): void {
    const stage = this.control.formData.crop_stages.find(s => s.id === stageId);
    if (!stage?.nutrient_requirement) return;

    const value = (stage.nutrient_requirement as any)[field];
    this.updateNutrientRequirement(stageId, { [field]: value });
  }
}
