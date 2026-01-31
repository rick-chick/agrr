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
        <h2 id="form-heading" class="form-card__title">{{ 'crops.edit.title' | translate }}</h2>
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
          </form>

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
                    <h4 class="crop-stage-card__title">{{ 'crops.edit.stage_title' | translate }} {{ stage.order }}</h4>
                    <button type="button" class="btn-danger btn-small" (click)="deleteCropStage(stage.id)">
                      {{ 'common.delete' | translate }}
                    </button>
                  </div>
                  <div class="crop-stage-card__content">
                    <label class="form-card__field">
                      <span class="form-card__field-label">{{ 'crops.edit.stage_name' | translate }}</span>
                      <input type="text" [(ngModel)]="stage.name" (blur)="updateCropStage(stage.id, { name: stage.name })" />
                    </label>
                    <label class="form-card__field">
                      <span class="form-card__field-label">{{ 'crops.edit.stage_order' | translate }}</span>
                      <input type="number" [(ngModel)]="stage.order" (blur)="updateCropStage(stage.id, { order: stage.order })" />
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
                            <input type="number" step="0.1" [(ngModel)]="stage.temperature_requirement?.base_temperature"
                                   (blur)="updateTemperatureRequirement(stage.id, { base_temperature: stage.temperature_requirement?.base_temperature })" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.optimal_min' | translate }}</span>
                            <input type="number" step="0.1" [(ngModel)]="stage.temperature_requirement?.optimal_min"
                                   (blur)="updateTemperatureRequirement(stage.id, { optimal_min: stage.temperature_requirement?.optimal_min })" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.optimal_max' | translate }}</span>
                            <input type="number" step="0.1" [(ngModel)]="stage.temperature_requirement?.optimal_max"
                                   (blur)="updateTemperatureRequirement(stage.id, { optimal_max: stage.temperature_requirement?.optimal_max })" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.low_stress_threshold' | translate }}</span>
                            <input type="number" step="0.1" [(ngModel)]="stage.temperature_requirement?.low_stress_threshold"
                                   (blur)="updateTemperatureRequirement(stage.id, { low_stress_threshold: stage.temperature_requirement?.low_stress_threshold })" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.high_stress_threshold' | translate }}</span>
                            <input type="number" step="0.1" [(ngModel)]="stage.temperature_requirement?.high_stress_threshold"
                                   (blur)="updateTemperatureRequirement(stage.id, { high_stress_threshold: stage.temperature_requirement?.high_stress_threshold })" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.frost_threshold' | translate }}</span>
                            <input type="number" step="0.1" [(ngModel)]="stage.temperature_requirement?.frost_threshold"
                                   (blur)="updateTemperatureRequirement(stage.id, { frost_threshold: stage.temperature_requirement?.frost_threshold })" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.sterility_risk_threshold' | translate }}</span>
                            <input type="number" step="0.1" [(ngModel)]="stage.temperature_requirement?.sterility_risk_threshold"
                                   (blur)="updateTemperatureRequirement(stage.id, { sterility_risk_threshold: stage.temperature_requirement?.sterility_risk_threshold })" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.max_temperature' | translate }}</span>
                            <input type="number" step="0.1" [(ngModel)]="stage.temperature_requirement?.max_temperature"
                                   (blur)="updateTemperatureRequirement(stage.id, { max_temperature: stage.temperature_requirement?.max_temperature })" />
                          </label>
                        </div>
                      </div>

                      <!-- Thermal Requirement -->
                      <div class="requirement-section">
                        <h5 class="requirement-section__title">{{ 'crops.edit.thermal_requirement' | translate }}</h5>
                        <div class="requirement-fields">
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.required_gdd' | translate }}</span>
                            <input type="number" step="0.1" [(ngModel)]="stage.thermal_requirement?.required_gdd"
                                   (blur)="updateThermalRequirement(stage.id, { required_gdd: stage.thermal_requirement?.required_gdd })" />
                          </label>
                        </div>
                      </div>

                      <!-- Sunshine Requirement -->
                      <div class="requirement-section">
                        <h5 class="requirement-section__title">{{ 'crops.edit.sunshine_requirement' | translate }}</h5>
                        <div class="requirement-fields">
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.minimum_sunshine_hours' | translate }}</span>
                            <input type="number" step="0.1" [(ngModel)]="stage.sunshine_requirement?.minimum_sunshine_hours"
                                   (blur)="updateSunshineRequirement(stage.id, { minimum_sunshine_hours: stage.sunshine_requirement?.minimum_sunshine_hours })" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.target_sunshine_hours' | translate }}</span>
                            <input type="number" step="0.1" [(ngModel)]="stage.sunshine_requirement?.target_sunshine_hours"
                                   (blur)="updateSunshineRequirement(stage.id, { target_sunshine_hours: stage.sunshine_requirement?.target_sunshine_hours })" />
                          </label>
                        </div>
                      </div>

                      <!-- Nutrient Requirement -->
                      <div class="requirement-section">
                        <h5 class="requirement-section__title">{{ 'crops.edit.nutrient_requirement' | translate }}</h5>
                        <div class="requirement-fields">
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.daily_uptake_n' | translate }}</span>
                            <input type="number" step="0.01" [(ngModel)]="stage.nutrient_requirement?.daily_uptake_n"
                                   (blur)="updateNutrientRequirement(stage.id, { daily_uptake_n: stage.nutrient_requirement?.daily_uptake_n })" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.daily_uptake_p' | translate }}</span>
                            <input type="number" step="0.01" [(ngModel)]="stage.nutrient_requirement?.daily_uptake_p"
                                   (blur)="updateNutrientRequirement(stage.id, { daily_uptake_p: stage.nutrient_requirement?.daily_uptake_p })" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.daily_uptake_k' | translate }}</span>
                            <input type="number" step="0.01" [(ngModel)]="stage.nutrient_requirement?.daily_uptake_k"
                                   (blur)="updateNutrientRequirement(stage.id, { daily_uptake_k: stage.nutrient_requirement?.daily_uptake_k })" />
                          </label>
                          <label class="form-card__field form-card__field--small">
                            <span class="form-card__field-label">{{ 'crops.edit.region' | translate }}</span>
                            <input type="text" [(ngModel)]="stage.nutrient_requirement?.region"
                                   (blur)="updateNutrientRequirement(stage.id, { region: stage.nutrient_requirement?.region })" />
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
}
