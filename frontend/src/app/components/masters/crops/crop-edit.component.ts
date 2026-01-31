import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { AuthService } from '../../../services/auth.service';
import { CropEditView, CropEditViewState, CropEditFormData } from './crop-edit.view';
import { LoadCropForEditUseCase } from '../../../usecase/crops/load-crop-for-edit.usecase';
import { UpdateCropUseCase } from '../../../usecase/crops/update-crop.usecase';
import { CreateCropStageUseCase } from '../../../usecase/crops/create-crop-stage.usecase';
import { UpdateCropStageUseCase } from '../../../usecase/crops/update-crop-stage.usecase';
import { DeleteCropStageUseCase } from '../../../usecase/crops/delete-crop-stage.usecase';
import { UpdateTemperatureRequirementUseCase } from '../../../usecase/crops/update-temperature-requirement.usecase';
import { UpdateThermalRequirementUseCase } from '../../../usecase/crops/update-thermal-requirement.usecase';
import { UpdateSunshineRequirementUseCase } from '../../../usecase/crops/update-sunshine-requirement.usecase';
import { UpdateNutrientRequirementUseCase } from '../../../usecase/crops/update-nutrient-requirement.usecase';
import { CropEditPresenter } from '../../../adapters/crops/crop-edit.presenter';
import { LOAD_CROP_FOR_EDIT_OUTPUT_PORT } from '../../../usecase/crops/load-crop-for-edit.output-port';
import { UPDATE_CROP_OUTPUT_PORT } from '../../../usecase/crops/update-crop.output-port';
import { CREATE_CROP_STAGE_OUTPUT_PORT } from '../../../usecase/crops/create-crop-stage.output-port';
import { UPDATE_CROP_STAGE_OUTPUT_PORT } from '../../../usecase/crops/update-crop-stage.output-port';
import { DELETE_CROP_STAGE_OUTPUT_PORT } from '../../../usecase/crops/delete-crop-stage.output-port';
import { UPDATE_TEMPERATURE_REQUIREMENT_OUTPUT_PORT } from '../../../usecase/crops/update-temperature-requirement.output-port';
import { UPDATE_THERMAL_REQUIREMENT_OUTPUT_PORT } from '../../../usecase/crops/update-thermal-requirement.output-port';
import { UPDATE_SUNSHINE_REQUIREMENT_OUTPUT_PORT } from '../../../usecase/crops/update-sunshine-requirement.output-port';
import { UPDATE_NUTRIENT_REQUIREMENT_OUTPUT_PORT } from '../../../usecase/crops/update-nutrient-requirement.output-port';
import { CROP_GATEWAY } from '../../../usecase/crops/crop-gateway';
import { CropApiGateway } from '../../../adapters/crops/crop-api.gateway';
import { CROP_STAGE_GATEWAY } from '../../../usecase/crops/crop-stage-gateway';
import { CropStageApiGateway } from '../../../adapters/crops/crop-stage-api.gateway';

const initialFormData: CropEditFormData = {
  name: '',
  variety: null,
  area_per_unit: null,
  revenue_per_area: null,
  region: null,
  groups: [],
  groupsDisplay: '',
  is_reference: false,
  crop_stages: []
};

function parseGroups(s: string): string[] {
  return (s || '')
    .split(',')
    .map((x) => x.trim())
    .filter(Boolean);
}

const initialControl: CropEditViewState = {
  loading: true,
  saving: false,
  error: null,
  formData: initialFormData
};

@Component({
  selector: 'app-crop-edit',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, TranslateModule],
  providers: [
    CropEditPresenter,
    LoadCropForEditUseCase,
    UpdateCropUseCase,
    CreateCropStageUseCase,
    UpdateCropStageUseCase,
    DeleteCropStageUseCase,
    UpdateTemperatureRequirementUseCase,
    UpdateThermalRequirementUseCase,
    UpdateSunshineRequirementUseCase,
    UpdateNutrientRequirementUseCase,
    { provide: LOAD_CROP_FOR_EDIT_OUTPUT_PORT, useExisting: CropEditPresenter },
    { provide: UPDATE_CROP_OUTPUT_PORT, useExisting: CropEditPresenter },
    { provide: CREATE_CROP_STAGE_OUTPUT_PORT, useExisting: CropEditPresenter },
    { provide: UPDATE_CROP_STAGE_OUTPUT_PORT, useExisting: CropEditPresenter },
    { provide: DELETE_CROP_STAGE_OUTPUT_PORT, useExisting: CropEditPresenter },
    { provide: UPDATE_TEMPERATURE_REQUIREMENT_OUTPUT_PORT, useExisting: CropEditPresenter },
    { provide: UPDATE_THERMAL_REQUIREMENT_OUTPUT_PORT, useExisting: CropEditPresenter },
    { provide: UPDATE_SUNSHINE_REQUIREMENT_OUTPUT_PORT, useExisting: CropEditPresenter },
    { provide: UPDATE_NUTRIENT_REQUIREMENT_OUTPUT_PORT, useExisting: CropEditPresenter },
    { provide: CROP_GATEWAY, useClass: CropApiGateway },
    { provide: CROP_STAGE_GATEWAY, useClass: CropStageApiGateway }
  ],
  template: `
    <main class="page-main">
      <section class="form-card" aria-labelledby="form-heading">
        @if (!control.loading) {
          <h2 id="form-heading" class="form-card__title">{{ control.formData.name }}を編集</h2>
        } @else {
          <h2 id="form-heading" class="form-card__title">{{ 'common.loading' | translate }}</h2>
        }
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else {
          <form (ngSubmit)="updateCrop()" #cropForm="ngForm" class="form-card__form">
            <label for="crop-name" class="form-card__field">
              <span class="form-card__field-label">{{ 'crops.form.name_label' | translate }}</span>
              <input id="crop-name" name="name" [(ngModel)]="control.formData.name" required />
            </label>
            <label for="crop-variety" class="form-card__field">
              <span class="form-card__field-label">{{ 'crops.form.variety_label' | translate }}</span>
              <input id="crop-variety" name="variety" [(ngModel)]="control.formData.variety" />
            </label>
            <label for="crop-area-per-unit" class="form-card__field">
              <span class="form-card__field-label">{{ 'crops.form.area_per_unit_label' | translate }}</span>
              <input id="crop-area-per-unit" name="area_per_unit" type="number" step="0.01" [(ngModel)]="control.formData.area_per_unit" />
            </label>
            <label for="crop-revenue-per-area" class="form-card__field">
              <span class="form-card__field-label">{{ 'crops.form.revenue_per_area_label' | translate }}</span>
              <input id="crop-revenue-per-area" name="revenue_per_area" type="number" step="0.01" [(ngModel)]="control.formData.revenue_per_area" />
            </label>
            <label for="crop-groups" class="form-card__field">
              <span class="form-card__field-label">{{ 'crops.form.groups_label' | translate }}</span>
              <input id="crop-groups" name="groups" [(ngModel)]="control.formData.groupsDisplay" [placeholder]="'crops.form.groups_placeholder' | translate" />
            </label>
            <label for="crop-region" class="form-card__field">
              <span class="form-card__field-label">{{ 'crops.form.region_label' | translate }}</span>
              <input id="crop-region" name="region" [(ngModel)]="control.formData.region" />
            </label>
            @if (auth.user()?.admin) {
              <label class="form-card__field form-card__field--checkbox">
                <input type="checkbox" name="is_reference" [(ngModel)]="control.formData.is_reference" />
                <span class="form-card__field-label">{{ 'crops.form.is_reference_label' | translate }}</span>
              </label>
            }
            <div class="form-card__actions">
              <button type="submit" class="btn-primary" [disabled]="cropForm.invalid || control.saving">
                {{ 'crops.form.submit_update' | translate }}
              </button>
              <a [routerLink]="['/crops']" class="btn-secondary">{{ 'common.back' | translate }}</a>
            </div>

            <!-- Crop Stages Section -->
          <section class="crop-stages-section" aria-labelledby="stages-heading">
            <h3 id="stages-heading" class="crop-stages-section__title">{{ 'crops.edit.stages_title' | translate }}</h3>
            <div class="crop-stages-section__actions">
              <button type="button" class="btn-secondary" (click)="addCropStage()">
                {{ 'crops.edit.add_stage' | translate }}
              </button>
            </div>
            <div class="crop-stages-list">
              @for (stage of control.formData.crop_stages; track stage.id) {
                <div class="crop-stage-card">
                  <div class="crop-stage-card__header">
                    <h4 class="crop-stage-card__title">ステージ {{ stage.order }}</h4>
                    <button type="button" class="btn-danger" (click)="deleteCropStage(stage.id)">
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
                      <input type="number" name="stage_order_{{ stage.id }}" [(ngModel)]="stage.order" (blur)="updateCropStage(stage.id, { order: stage.order })" />
                    </label>

                    <!-- Requirements Section -->
                    <details class="crop-stage-requirements">
                      <summary class="crop-stage-requirements__summary">{{ 'crops.edit.requirements_title' | translate }}</summary>

                      <!-- Temperature Requirement -->
                      <div class="requirement-section">
                        <h5 class="requirement-section__title">{{ 'crops.edit.temperature_requirement' | translate }}</h5>
                        <div class="requirement-fields">
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.base_temperature' | translate }}</span>
                            <input type="number" step="0.1" name="temp_base_{{ stage.id }}" [ngModel]="stage.temperature_requirement?.base_temperature ?? null"
                                   (ngModelChange)="onTemperatureFieldChange(stage.id, 'base_temperature', $event)" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.optimal_min' | translate }}</span>
                            <input type="number" step="0.1" name="temp_opt_min_{{ stage.id }}" [ngModel]="stage.temperature_requirement?.optimal_min ?? null"
                                   (ngModelChange)="onTemperatureFieldChange(stage.id, 'optimal_min', $event)" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.optimal_max' | translate }}</span>
                            <input type="number" step="0.1" name="temp_opt_max_{{ stage.id }}" [ngModel]="stage.temperature_requirement?.optimal_max ?? null"
                                   (ngModelChange)="onTemperatureFieldChange(stage.id, 'optimal_max', $event)" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.low_stress_threshold' | translate }}</span>
                            <input type="number" step="0.1" name="temp_low_stress_{{ stage.id }}" [ngModel]="stage.temperature_requirement?.low_stress_threshold ?? null"
                                   (ngModelChange)="onTemperatureFieldChange(stage.id, 'low_stress_threshold', $event)" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.high_stress_threshold' | translate }}</span>
                            <input type="number" step="0.1" name="temp_high_stress_{{ stage.id }}" [ngModel]="stage.temperature_requirement?.high_stress_threshold ?? null"
                                   (ngModelChange)="onTemperatureFieldChange(stage.id, 'high_stress_threshold', $event)" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.frost_threshold' | translate }}</span>
                            <input type="number" step="0.1" name="temp_frost_{{ stage.id }}" [ngModel]="stage.temperature_requirement?.frost_threshold ?? null"
                                   (ngModelChange)="onTemperatureFieldChange(stage.id, 'frost_threshold', $event)" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.sterility_risk_threshold' | translate }}</span>
                            <input type="number" step="0.1" name="temp_sterility_{{ stage.id }}" [ngModel]="stage.temperature_requirement?.sterility_risk_threshold ?? null"
                                   (ngModelChange)="onTemperatureFieldChange(stage.id, 'sterility_risk_threshold', $event)" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.max_temperature' | translate }}</span>
                            <input type="number" step="0.1" name="temp_max_{{ stage.id }}" [ngModel]="stage.temperature_requirement?.max_temperature ?? null"
                                   (ngModelChange)="onTemperatureFieldChange(stage.id, 'max_temperature', $event)" />
                          </label>
                        </div>
                      </div>

                      <!-- Thermal Requirement -->
                      <div class="requirement-section">
                        <h5 class="requirement-section__title">{{ 'crops.edit.thermal_requirement' | translate }}</h5>
                        <div class="requirement-fields">
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.required_gdd' | translate }}</span>
                            <input type="number" step="0.1" name="thermal_gdd_{{ stage.id }}" [ngModel]="stage.thermal_requirement?.required_gdd ?? null"
                                   (ngModelChange)="onThermalFieldChange(stage.id, 'required_gdd', $event)" />
                          </label>
                        </div>
                      </div>

                      <!-- Sunshine Requirement -->
                      <div class="requirement-section">
                        <h5 class="requirement-section__title">{{ 'crops.edit.sunshine_requirement' | translate }}</h5>
                        <div class="requirement-fields">
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.minimum_sunshine_hours' | translate }}</span>
                            <input type="number" step="0.1" name="sunshine_min_{{ stage.id }}" [ngModel]="stage.sunshine_requirement?.minimum_sunshine_hours ?? null"
                                   (ngModelChange)="onSunshineFieldChange(stage.id, 'minimum_sunshine_hours', $event)" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.target_sunshine_hours' | translate }}</span>
                            <input type="number" step="0.1" name="sunshine_target_{{ stage.id }}" [ngModel]="stage.sunshine_requirement?.target_sunshine_hours ?? null"
                                   (ngModelChange)="onSunshineFieldChange(stage.id, 'target_sunshine_hours', $event)" />
                          </label>
                        </div>
                      </div>

                      <!-- Nutrient Requirement -->
                      <div class="requirement-section">
                        <h5 class="requirement-section__title">{{ 'crops.edit.nutrient_requirement' | translate }}</h5>
                        <div class="requirement-fields">
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.daily_uptake_n' | translate }}</span>
                            <input type="number" step="0.01" name="nutrient_n_{{ stage.id }}" [ngModel]="stage.nutrient_requirement?.daily_uptake_n ?? null"
                                   (ngModelChange)="onNutrientFieldChange(stage.id, 'daily_uptake_n', $event)" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.daily_uptake_p' | translate }}</span>
                            <input type="number" step="0.01" name="nutrient_p_{{ stage.id }}" [ngModel]="stage.nutrient_requirement?.daily_uptake_p ?? null"
                                   (ngModelChange)="onNutrientFieldChange(stage.id, 'daily_uptake_p', $event)" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.daily_uptake_k' | translate }}</span>
                            <input type="number" step="0.01" name="nutrient_k_{{ stage.id }}" [ngModel]="stage.nutrient_requirement?.daily_uptake_k ?? null"
                                   (ngModelChange)="onNutrientFieldChange(stage.id, 'daily_uptake_k', $event)" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.region' | translate }}</span>
                            <input type="text" name="nutrient_region_{{ stage.id }}" [ngModel]="stage.nutrient_requirement?.region ?? null"
                                   (ngModelChange)="onNutrientFieldChange(stage.id, 'region', $event)" />
                          </label>
                        </div>
                      </div>
                    </details>
                  </div>
                </div>
              }
            </div>
          </section>
          </form>
        }
      </section>
    </main>
  `,
  styleUrl: './crop-edit.component.css'
})
export class CropEditComponent implements CropEditView, OnInit {
  readonly auth = inject(AuthService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly loadUseCase = inject(LoadCropForEditUseCase);
  private readonly updateUseCase = inject(UpdateCropUseCase);
  private readonly createCropStageUseCase = inject(CreateCropStageUseCase);
  private readonly updateCropStageUseCase = inject(UpdateCropStageUseCase);
  private readonly deleteCropStageUseCase = inject(DeleteCropStageUseCase);
  private readonly updateTemperatureRequirementUseCase = inject(UpdateTemperatureRequirementUseCase);
  private readonly updateThermalRequirementUseCase = inject(UpdateThermalRequirementUseCase);
  private readonly updateSunshineRequirementUseCase = inject(UpdateSunshineRequirementUseCase);
  private readonly updateNutrientRequirementUseCase = inject(UpdateNutrientRequirementUseCase);
  private readonly presenter = inject(CropEditPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: CropEditViewState = initialControl;
  get control(): CropEditViewState {
    return this._control;
  }
  set control(value: CropEditViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  private get cropId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    if (!this.cropId) {
      this.control = { ...initialControl, loading: false, error: 'Invalid crop id.' };
      return;
    }
    this.loadUseCase.execute({ cropId: this.cropId });
  }

  updateCrop(): void {
    if (this.control.saving) return;
    this.control = { ...this.control, saving: true, error: null };
    const fd = this.control.formData;
    this.updateUseCase.execute({
      cropId: this.cropId,
      name: fd.name,
      variety: fd.variety,
      area_per_unit: fd.area_per_unit,
      revenue_per_area: fd.revenue_per_area,
      region: fd.region,
      groups: parseGroups(fd.groupsDisplay),
      is_reference: fd.is_reference,
      onSuccess: () => this.router.navigate(['/crops', this.cropId])
    });
  }

  addCropStage(): void {
    const nextOrder = Math.max(0, ...this.control.formData.crop_stages.map(s => s.order)) + 1;
    this.createCropStageUseCase.execute({
      cropId: this.cropId,
      payload: {
        name: `Stage ${nextOrder}`,
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
    if (confirm('Are you sure you want to delete this crop stage?')) {
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

  // Helper methods for requirement field changes
  onTemperatureFieldChange(stageId: number, field: string, value: number | null): void {
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
    this.updateTemperatureRequirement(stageId, { [field]: value } as any);
  }

  onThermalFieldChange(stageId: number, field: string, value: number | null): void {
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
    this.updateThermalRequirement(stageId, { [field]: value } as any);
  }

  onSunshineFieldChange(stageId: number, field: string, value: number | null): void {
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
    this.updateSunshineRequirement(stageId, { [field]: value } as any);
  }

  onNutrientFieldChange(stageId: number, field: string, value: number | string | null): void {
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
    this.updateNutrientRequirement(stageId, { [field]: value } as any);
  }
}
