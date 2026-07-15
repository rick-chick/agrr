import { Component, OnInit, inject, ChangeDetectorRef, ViewChild, ElementRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { CdkDragDrop, DragDropModule } from '@angular/cdk/drag-drop';
import { CropStagesView, CropStagesViewState, CropStagesFormData } from './crop-stages.view';
import { LoadCropForEditUseCase } from '../../../usecase/crops/load-crop-for-edit.usecase';
import { CreateCropStageUseCase } from '../../../usecase/crops/create-crop-stage.usecase';
import { UpdateCropStageUseCase } from '../../../usecase/crops/update-crop-stage.usecase';
import { ReorderCropStagesUseCase } from '../../../usecase/crops/reorder-crop-stages.usecase';
import { DeleteCropStageUseCase } from '../../../usecase/crops/delete-crop-stage.usecase';
import { LoadCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/load-crop-task-schedule-blueprints.usecase';
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
import {
  defaultBlueprintReadiness
} from '../../../domain/crops/blueprint-generation-readiness';
import { stageCumulativeGddRange } from '../../../domain/crops/stage-cumulative-gdd';
import {
  findDuplicateStageOrders,
  reorderStagesByIndex,
  sortStagesByOrder
} from '../../../domain/crops/crop-stage-order';
import type { CropStage } from '../../../domain/crops/crop';
import { countLinkedTaskScheduleBlueprints } from '../../../domain/crops/stage-linked-blueprint-count';
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
  blueprintReadiness: defaultBlueprintReadiness(),
  taskScheduleBlueprints: [],
  pendingErrorFlash: null,
  pendingSuccessFlash: null
};

export interface StageEditDraft {
  name: string;
  base_temperature: number | null;
  optimal_min: number | null;
  optimal_max: number | null;
  max_temperature: number | null;
  required_gdd: number | null;
}

interface TemperatureDetailDraft {
  low_stress_threshold: number | null;
  high_stress_threshold: number | null;
  frost_threshold: number | null;
}

interface AdvancedDetailDraft {
  minimum_sunshine_hours: number | null;
  target_sunshine_hours: number | null;
  daily_uptake_n: number | null;
  daily_uptake_p: number | null;
  daily_uptake_k: number | null;
  region: string | null;
  sterility_risk_threshold: number | null;
}

interface TemperatureScaleMarker {
  key: 'base' | 'optimal_min' | 'optimal_max' | 'max';
  position: number;
}

interface TemperatureScaleBand {
  left: number;
  width: number;
}

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

          @if (duplicateStageOrders.length > 0) {
            <p class="crop-stages-order-warning" role="alert">
              {{
                'crops.edit.stage_order_duplicate'
                  | translate: { orders: duplicateStageOrders.join(', ') }
              }}
            </p>
          }

          @if (control.formData.crop_stages.length === 0) {
            <div class="crop-stages-empty">
              <p class="crop-stages-empty__lead">{{ 'crops.edit.stages_empty_lead' | translate }}</p>
              <p class="crop-stages-empty__description">{{ 'crops.show.no_stages_description' | translate }}</p>
              <button type="button" class="btn btn-primary crop-stages-empty__cta" (click)="addCropStage()">
                {{ 'crops.edit.add_stage' | translate }}
              </button>
            </div>
          } @else {
            <table class="crop-stages-table">
              <thead>
                <tr>
                  <th class="crop-stages-table__col-drag" scope="col" aria-hidden="true"></th>
                  <th scope="col">{{ 'crops.edit.table_order' | translate }}</th>
                  <th scope="col">{{ 'crops.edit.table_stage_name' | translate }}</th>
                  <th scope="col">{{ 'crops.edit.table_base_temperature' | translate }}</th>
                  <th scope="col">{{ 'crops.edit.table_required_gdd' | translate }}</th>
                  <th scope="col">{{ 'crops.edit.table_cumulative_gdd' | translate }}</th>
                </tr>
              </thead>
              <tbody
                cdkDropList
                [cdkDropListData]="sortedStages"
                (cdkDropListDropped)="onStageDropped($event)"
              >
                @for (stage of sortedStages; track stage.id) {
                  <tr
                    class="crop-stages-table__row"
                    cdkDrag
                    [cdkDragData]="stage"
                    [class.crop-stages-table__row--selected]="selectedStageId === stage.id"
                    (click)="selectStage(stage.id)"
                  >
                    <td class="crop-stages-table__drag" cdkDragHandle (click)="$event.stopPropagation()">
                      <span class="crop-stages-table__drag-icon" aria-hidden="true">≡</span>
                    </td>
                    <td>{{ stage.order }}</td>
                    <td>{{ stage.name }}</td>
                    <td>{{ formatOptionalNumber(stage.temperature_requirement?.base_temperature) }}</td>
                    <td>{{ formatOptionalNumber(stage.thermal_requirement?.required_gdd) }}</td>
                    <td>{{ formatCumulativeGdd(stage) }}</td>
                  </tr>
                }
                <tr class="crop-stages-table__add-row">
                  <td colspan="6">
                    <button type="button" class="crop-stages-table__add-button" (click)="addCropStage()">
                      {{ 'crops.edit.add_stage' | translate }}
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>

            @if (selectedStage; as stage) {
              <div class="crop-stages-edit-panel">
                <div class="crop-stages-edit-panel__header">
                  <span class="crop-stages-edit-panel__stage-badge">{{ stage.order }}</span>
                  <label class="form-card__field crop-stages-edit-panel__name-field">
                    <span class="form-card__field-label">{{ 'crops.edit.stage_name' | translate }}</span>
                    <input
                      type="text"
                      name="panel_stage_name"
                      [(ngModel)]="stageEditDraft.name"
                    />
                  </label>
                </div>

                <section class="crop-stages-edit-panel__subsection crop-stages-edit-panel__subsection--temperature">
                  <h4 class="crop-stages-edit-panel__subsection-title">
                    {{ 'crops.edit.temperature_section' | translate }}
                  </h4>
                  @if (hasTemperatureScale()) {
                    <div class="crop-stages-edit-panel__temperature-scale" aria-hidden="true">
                      <div class="crop-stages-edit-panel__temperature-scale-track">
                        @if (temperatureScaleBand(); as band) {
                          <div
                            class="crop-stages-edit-panel__temperature-scale-band"
                            [style.left.%]="band.left"
                            [style.width.%]="band.width"
                          ></div>
                        }
                        @for (marker of temperatureScaleMarkers(); track marker.key) {
                          <span
                            [class]="
                              'crop-stages-edit-panel__temperature-scale-marker crop-stages-edit-panel__temperature-scale-marker--' +
                              marker.key
                            "
                            [style.left.%]="marker.position"
                          ></span>
                        }
                      </div>
                    </div>
                  }
                  <div class="crop-stages-edit-panel__temperature-fields">
                    <label class="form-card__field form-card__field--small">
                      <span class="form-card__field-label">{{ 'crops.edit.base_temperature' | translate }}</span>
                      <input
                        type="number"
                        step="0.1"
                        name="panel_base_temperature"
                        [placeholder]="'crops.edit.base_temperature_placeholder' | translate"
                        [(ngModel)]="stageEditDraft.base_temperature"
                      />
                      <p class="form-hint">{{ 'crops.edit.base_temperature_help' | translate }}</p>
                    </label>
                    <div class="crop-stages-edit-panel__optimal-group">
                      <span class="crop-stages-edit-panel__optimal-group-label">{{
                        'crops.edit.optimal_range' | translate
                      }}</span>
                      <div class="crop-stages-edit-panel__optimal-group-fields">
                        <label class="form-card__field form-card__field--small">
                          <span class="form-card__field-label">{{ 'crops.edit.optimal_min' | translate }}</span>
                          <input
                            type="number"
                            step="0.1"
                            name="panel_optimal_min"
                            [(ngModel)]="stageEditDraft.optimal_min"
                          />
                        </label>
                        <label class="form-card__field form-card__field--small">
                          <span class="form-card__field-label">{{ 'crops.edit.optimal_max' | translate }}</span>
                          <input
                            type="number"
                            step="0.1"
                            name="panel_optimal_max"
                            [(ngModel)]="stageEditDraft.optimal_max"
                          />
                        </label>
                      </div>
                    </div>
                    <label class="form-card__field form-card__field--small">
                      <span class="form-card__field-label">{{ 'crops.edit.max_temperature' | translate }}</span>
                      <input
                        type="number"
                        step="0.1"
                        name="panel_max_temperature"
                        [(ngModel)]="stageEditDraft.max_temperature"
                      />
                    </label>
                  </div>
                </section>

                <section class="crop-stages-edit-panel__subsection crop-stages-edit-panel__subsection--gdd">
                  <h4 class="crop-stages-edit-panel__subsection-title">
                    {{ 'crops.edit.gdd_section' | translate }}
                  </h4>
                  <div class="crop-stages-edit-panel__gdd-block">
                    <label class="form-card__field form-card__field--small">
                      <span class="form-card__field-label">{{ 'crops.edit.required_gdd' | translate }}</span>
                      <input
                        type="number"
                        step="0.1"
                        name="panel_required_gdd"
                        [placeholder]="'crops.edit.required_gdd_placeholder' | translate"
                        [(ngModel)]="stageEditDraft.required_gdd"
                      />
                      <p class="form-hint">{{ 'crops.edit.required_gdd_help' | translate }}</p>
                    </label>
                  </div>
                </section>

                <section class="crop-stages-edit-panel__subsection crop-stages-edit-panel__subsection--details">
                  <h4 class="crop-stages-edit-panel__subsection-title">
                    {{ 'crops.edit.details_section' | translate }}
                  </h4>
                  <div class="crop-stages-edit-panel__detail-chips">
                    <button
                      type="button"
                      class="crop-stages-edit-panel__detail-chip"
                      (click)="openTemperatureDialog()"
                    >
                      {{ 'crops.edit.edit_temperature_details' | translate }}
                      <span class="crop-stages-edit-panel__detail-chip-chevron" aria-hidden="true">›</span>
                    </button>
                    <button
                      type="button"
                      class="crop-stages-edit-panel__detail-chip"
                      (click)="openAdvancedDialog()"
                    >
                      {{ 'crops.edit.edit_sunshine_nutrient' | translate }}
                      <span class="crop-stages-edit-panel__detail-chip-chevron" aria-hidden="true">›</span>
                    </button>
                  </div>
                </section>

                <div class="crop-stages-edit-panel__footer">
                  <button type="button" class="btn btn-primary" (click)="saveStagePanel()">
                    {{ 'crops.edit.save_stage' | translate }}
                  </button>
                  <button type="button" class="btn btn-danger" (click)="deleteCropStage(stage.id)">
                    {{ 'common.delete' | translate }}
                  </button>
                </div>
              </div>
            }
          }
        </section>
      }
    </main>

    <dialog
      #deleteConfirmDialog
      class="confirm-dialog crop-stages__delete-confirm"
      (cancel)="cancelDeleteConfirmDialog($event)"
      (click)="onDeleteConfirmDialogBackdropClick($event)"
    >
      @if (pendingDeleteStage) {
        <p class="confirm-dialog__message">{{
          'crops.stage.delete_confirm_message' | translate:{ stageName: pendingDeleteStage.name }
        }}</p>
        @if (pendingDeleteBlueprintCount > 0) {
          <p class="confirm-dialog__warning" role="alert">{{
            'crops.stage.delete_confirm_blueprint_warning' | translate:{ count: pendingDeleteBlueprintCount }
          }}</p>
        }
        <div class="confirm-dialog__actions">
          <button type="button" class="btn-secondary" (click)="cancelDeleteConfirmDialog()">
            {{ 'common.cancel' | translate }}
          </button>
          <button type="button" class="btn-danger" (click)="confirmDeleteCropStage()">
            {{ 'common.delete' | translate }}
          </button>
        </div>
      }
    </dialog>

    <dialog
      #unsavedConfirmDialog
      class="confirm-dialog crop-stages__unsaved-confirm"
      (cancel)="cancelUnsavedConfirmDialog($event)"
      (click)="onUnsavedConfirmDialogBackdropClick($event)"
    >
      @if (pendingStageSwitchId != null) {
        <p class="confirm-dialog__message">{{ 'crops.edit.unsaved_confirm_message' | translate }}</p>
        <div class="confirm-dialog__actions">
          <button type="button" class="btn-secondary" (click)="cancelUnsavedConfirmDialog()">
            {{ 'common.cancel' | translate }}
          </button>
          <button type="button" class="btn-primary" (click)="confirmDiscardAndSwitchStage()">
            {{ 'common.confirm' | translate }}
          </button>
        </div>
      }
    </dialog>

    <dialog
      #temperatureDialog
      class="confirm-dialog crop-stages__temperature-dialog"
      (cancel)="cancelTemperatureDialog($event)"
      (click)="onTemperatureDialogBackdropClick($event)"
    >
      @if (temperatureDetailDraft) {
        <h2 class="crop-stages-dialog__title">{{ 'crops.edit.temperature_details_title' | translate }}</h2>
        <div class="crop-stages-dialog__fields">
          <label class="form-card__field form-card__field--small">
            <span class="form-card__field-label">{{ 'crops.edit.low_stress_threshold' | translate }}</span>
            <input type="number" step="0.1" name="temp_low_stress" [(ngModel)]="temperatureDetailDraft.low_stress_threshold" />
          </label>
          <label class="form-card__field form-card__field--small">
            <span class="form-card__field-label">{{ 'crops.edit.high_stress_threshold' | translate }}</span>
            <input type="number" step="0.1" name="temp_high_stress" [(ngModel)]="temperatureDetailDraft.high_stress_threshold" />
          </label>
          <label class="form-card__field form-card__field--small">
            <span class="form-card__field-label">{{ 'crops.edit.frost_threshold' | translate }}</span>
            <input type="number" step="0.1" name="temp_frost" [(ngModel)]="temperatureDetailDraft.frost_threshold" />
          </label>
        </div>
        <div class="confirm-dialog__actions">
          <button type="button" class="btn-secondary" (click)="cancelTemperatureDialog()">
            {{ 'common.cancel' | translate }}
          </button>
          <button type="button" class="btn-primary" (click)="saveTemperatureDialog()">
            {{ 'crops.edit.save_stage' | translate }}
          </button>
        </div>
      }
    </dialog>

    <dialog
      #advancedDialog
      class="confirm-dialog crop-stages__advanced-dialog"
      (cancel)="cancelAdvancedDialog($event)"
      (click)="onAdvancedDialogBackdropClick($event)"
    >
      @if (advancedDetailDraft) {
        <h2 class="crop-stages-dialog__title">{{ 'crops.edit.advanced_details_title' | translate }}</h2>
        <div class="crop-stages-dialog__fields">
          <label class="form-card__field form-card__field--small">
            <span class="form-card__field-label">{{ 'crops.edit.minimum_sunshine_hours' | translate }}</span>
            <input type="number" step="0.1" name="sunshine_min" [(ngModel)]="advancedDetailDraft.minimum_sunshine_hours" />
          </label>
          <label class="form-card__field form-card__field--small">
            <span class="form-card__field-label">{{ 'crops.edit.target_sunshine_hours' | translate }}</span>
            <input type="number" step="0.1" name="sunshine_target" [(ngModel)]="advancedDetailDraft.target_sunshine_hours" />
          </label>
          <label class="form-card__field form-card__field--small">
            <span class="form-card__field-label">{{ 'crops.edit.daily_uptake_n' | translate }}</span>
            <input type="number" step="0.01" name="nutrient_n" [(ngModel)]="advancedDetailDraft.daily_uptake_n" />
          </label>
          <label class="form-card__field form-card__field--small">
            <span class="form-card__field-label">{{ 'crops.edit.daily_uptake_p' | translate }}</span>
            <input type="number" step="0.01" name="nutrient_p" [(ngModel)]="advancedDetailDraft.daily_uptake_p" />
          </label>
          <label class="form-card__field form-card__field--small">
            <span class="form-card__field-label">{{ 'crops.edit.daily_uptake_k' | translate }}</span>
            <input type="number" step="0.01" name="nutrient_k" [(ngModel)]="advancedDetailDraft.daily_uptake_k" />
          </label>
          <label class="form-card__field form-card__field--small">
            <span class="form-card__field-label">{{ 'crops.edit.region' | translate }}</span>
            <input type="text" name="nutrient_region" [(ngModel)]="advancedDetailDraft.region" />
          </label>
          <label class="form-card__field form-card__field--small">
            <span class="form-card__field-label">{{ 'crops.edit.sterility_risk_threshold' | translate }}</span>
            <input type="number" step="0.1" name="temp_sterility" [(ngModel)]="advancedDetailDraft.sterility_risk_threshold" />
          </label>
        </div>
        <div class="confirm-dialog__actions">
          <button type="button" class="btn-secondary" (click)="cancelAdvancedDialog()">
            {{ 'common.cancel' | translate }}
          </button>
          <button type="button" class="btn-primary" (click)="saveAdvancedDialog()">
            {{ 'crops.edit.save_stage' | translate }}
          </button>
        </div>
      }
    </dialog>
  `,
  styleUrls: ['./crop-stages.component.css']
})
export class CropStagesComponent implements CropStagesView, OnInit {
  @ViewChild('deleteConfirmDialog') deleteConfirmDialogRef?: ElementRef<HTMLDialogElement>;
  @ViewChild('unsavedConfirmDialog') unsavedConfirmDialogRef?: ElementRef<HTMLDialogElement>;
  @ViewChild('temperatureDialog') temperatureDialogRef?: ElementRef<HTMLDialogElement>;
  @ViewChild('advancedDialog') advancedDialogRef?: ElementRef<HTMLDialogElement>;

  private readonly route = inject(ActivatedRoute);
  private readonly loadUseCase = inject(LoadCropForEditUseCase);
  private readonly loadBlueprintsUseCase = inject(LoadCropTaskScheduleBlueprintsUseCase);
  private readonly createCropStageUseCase = inject(CreateCropStageUseCase);
  private readonly updateCropStageUseCase = inject(UpdateCropStageUseCase);
  private readonly reorderCropStagesUseCase = inject(ReorderCropStagesUseCase);
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
  private knownStageIds = new Set<number>();

  get control(): CropStagesViewState {
    return this._control;
  }
  set control(value: CropStagesViewState) {
    const previousStages = this._control.formData.crop_stages;
    this._control = applyPendingFlashViewEffects(value, { flash: this.flashMessage });
    const stagesChanged = previousStages !== value.formData.crop_stages;
    if (stagesChanged) {
      queueMicrotask(() => {
        this.ensureSelectedStage();
        this.cdr.markForCheck();
      });
    }
  }

  selectedStageId: number | null = null;
  stageEditDraft: StageEditDraft = {
    name: '',
    base_temperature: null,
    optimal_min: null,
    optimal_max: null,
    max_temperature: null,
    required_gdd: null
  };
  temperatureDetailDraft: TemperatureDetailDraft | null = null;
  advancedDetailDraft: AdvancedDetailDraft | null = null;
  pendingStageSwitchId: number | null = null;

  get cropId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  fromPlanId: number | null = null;
  returnTab: PlanWizardReturnTab = 'task_schedule';
  pendingDeleteStage: CropStage | null = null;

  get pendingDeleteBlueprintCount(): number {
    if (!this.pendingDeleteStage) {
      return 0;
    }
    return countLinkedTaskScheduleBlueprints(
      this.pendingDeleteStage.order,
      this.control.taskScheduleBlueprints
    );
  }

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

  get sortedStages(): CropStage[] {
    return sortStagesByOrder(this.control.formData.crop_stages);
  }

  get duplicateStageOrders(): number[] {
    return findDuplicateStageOrders(this.control.formData.crop_stages);
  }

  get selectedStage(): CropStage | null {
    if (this.selectedStageId == null) {
      return null;
    }
    return this.control.formData.crop_stages.find((stage) => stage.id === this.selectedStageId) ?? null;
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
    this.loadBlueprintsUseCase.execute({ cropId: this.cropId });
  }

  addCropStage(): void {
    const nextOrder = Math.max(0, ...this.control.formData.crop_stages.map((s) => s.order)) + 1;
    const defaultStageName = this.translate.instant('crops.stage.default_name', { order: nextOrder });
    this.createCropStageUseCase.execute({
      cropId: this.cropId,
      payload: {
        name: defaultStageName,
        order: nextOrder
      }
    });
  }

  selectStage(stageId: number): void {
    if (this.selectedStageId === stageId) {
      return;
    }
    if (this.isPanelDirty()) {
      this.pendingStageSwitchId = stageId;
      this.unsavedConfirmDialogRef?.nativeElement?.showModal();
      return;
    }
    this.selectStageImmediate(stageId);
  }

  selectStageImmediate(stageId: number): void {
    this.selectedStageId = stageId;
    const stage = this.selectedStage;
    if (stage) {
      this.syncDraftFromStage(stage);
    }
  }

  confirmDiscardAndSwitchStage(): void {
    const targetId = this.pendingStageSwitchId;
    this.pendingStageSwitchId = null;
    this.unsavedConfirmDialogRef?.nativeElement?.close();
    if (targetId != null) {
      this.selectStageImmediate(targetId);
    }
  }

  cancelUnsavedConfirmDialog(event?: Event): void {
    event?.preventDefault();
    this.pendingStageSwitchId = null;
    this.unsavedConfirmDialogRef?.nativeElement?.close();
  }

  onUnsavedConfirmDialogBackdropClick(event: MouseEvent): void {
    if (event.target === this.unsavedConfirmDialogRef?.nativeElement) {
      this.cancelUnsavedConfirmDialog();
    }
  }

  saveStagePanel(): void {
    const stage = this.selectedStage;
    if (!stage) {
      return;
    }

    if (this.stageEditDraft.name !== stage.name) {
      this.updateCropStage(stage.id, { name: this.stageEditDraft.name });
    }

    const temp = stage.temperature_requirement;
    const temperaturePatch: Record<string, number | null> = {};
    const panelTemperatureFields = [
      ['base_temperature', this.stageEditDraft.base_temperature],
      ['optimal_min', this.stageEditDraft.optimal_min],
      ['optimal_max', this.stageEditDraft.optimal_max],
      ['max_temperature', this.stageEditDraft.max_temperature]
    ] as const;
    for (const [field, draftValue] of panelTemperatureFields) {
      const currentValue = temp?.[field] ?? null;
      if (draftValue !== currentValue) {
        temperaturePatch[field] = draftValue;
      }
    }
    if (Object.keys(temperaturePatch).length > 0) {
      this.updateTemperatureRequirement(stage.id, temperaturePatch);
    }

    const currentRequiredGdd = stage.thermal_requirement?.required_gdd ?? null;
    if (this.stageEditDraft.required_gdd !== currentRequiredGdd) {
      this.updateThermalRequirement(stage.id, { required_gdd: this.stageEditDraft.required_gdd });
    }

    this.syncDraftFromStage(stage);
  }

  openTemperatureDialog(): void {
    const stage = this.selectedStage;
    if (!stage) {
      return;
    }
    const temp = stage.temperature_requirement;
    this.temperatureDetailDraft = {
      low_stress_threshold: temp?.low_stress_threshold ?? null,
      high_stress_threshold: temp?.high_stress_threshold ?? null,
      frost_threshold: temp?.frost_threshold ?? null
    };
    this.temperatureDialogRef?.nativeElement?.showModal();
  }

  saveTemperatureDialog(): void {
    const stage = this.selectedStage;
    if (!stage || !this.temperatureDetailDraft) {
      return;
    }
    this.updateTemperatureRequirement(stage.id, { ...this.temperatureDetailDraft });
    this.temperatureDetailDraft = null;
    this.temperatureDialogRef?.nativeElement?.close();
  }

  cancelTemperatureDialog(event?: Event): void {
    event?.preventDefault();
    this.temperatureDetailDraft = null;
    this.temperatureDialogRef?.nativeElement?.close();
  }

  onTemperatureDialogBackdropClick(event: MouseEvent): void {
    if (event.target === this.temperatureDialogRef?.nativeElement) {
      this.cancelTemperatureDialog();
    }
  }

  openAdvancedDialog(): void {
    const stage = this.selectedStage;
    if (!stage) {
      return;
    }
    const sunshine = stage.sunshine_requirement;
    const nutrient = stage.nutrient_requirement;
    const temp = stage.temperature_requirement;
    this.advancedDetailDraft = {
      minimum_sunshine_hours: sunshine?.minimum_sunshine_hours ?? null,
      target_sunshine_hours: sunshine?.target_sunshine_hours ?? null,
      daily_uptake_n: nutrient?.daily_uptake_n ?? null,
      daily_uptake_p: nutrient?.daily_uptake_p ?? null,
      daily_uptake_k: nutrient?.daily_uptake_k ?? null,
      region: nutrient?.region ?? null,
      sterility_risk_threshold: temp?.sterility_risk_threshold ?? null
    };
    this.advancedDialogRef?.nativeElement?.showModal();
  }

  saveAdvancedDialog(): void {
    const stage = this.selectedStage;
    if (!stage || !this.advancedDetailDraft) {
      return;
    }
    const {
      minimum_sunshine_hours,
      target_sunshine_hours,
      daily_uptake_n,
      daily_uptake_p,
      daily_uptake_k,
      region,
      sterility_risk_threshold
    } = this.advancedDetailDraft;

    this.updateSunshineRequirement(stage.id, {
      minimum_sunshine_hours,
      target_sunshine_hours
    });
    this.updateNutrientRequirement(stage.id, {
      daily_uptake_n,
      daily_uptake_p,
      daily_uptake_k,
      region
    });
    this.updateTemperatureRequirement(stage.id, { sterility_risk_threshold });

    this.advancedDetailDraft = null;
    this.advancedDialogRef?.nativeElement?.close();
  }

  cancelAdvancedDialog(event?: Event): void {
    event?.preventDefault();
    this.advancedDetailDraft = null;
    this.advancedDialogRef?.nativeElement?.close();
  }

  onAdvancedDialogBackdropClick(event: MouseEvent): void {
    if (event.target === this.advancedDialogRef?.nativeElement) {
      this.cancelAdvancedDialog();
    }
  }

  updateCropStage(stageId: number, payload: { name?: string; order?: number }): void {
    this.updateCropStageUseCase.execute({
      cropId: this.cropId,
      stageId,
      payload
    });
  }

  deleteCropStage(stageId: number): void {
    const stage = this.control.formData.crop_stages.find((item) => item.id === stageId);
    if (!stage) {
      return;
    }
    this.pendingDeleteStage = stage;
    this.deleteConfirmDialogRef?.nativeElement?.showModal();
  }

  confirmDeleteCropStage(): void {
    if (!this.pendingDeleteStage) {
      return;
    }
    const stageId = this.pendingDeleteStage.id;
    this.pendingDeleteStage = null;
    this.deleteConfirmDialogRef?.nativeElement?.close();
    this.deleteCropStageUseCase.execute({
      cropId: this.cropId,
      stageId
    });
  }

  cancelDeleteConfirmDialog(event?: Event): void {
    event?.preventDefault();
    this.pendingDeleteStage = null;
    this.deleteConfirmDialogRef?.nativeElement?.close();
  }

  onDeleteConfirmDialogBackdropClick(event: MouseEvent): void {
    if (event.target === this.deleteConfirmDialogRef?.nativeElement) {
      this.cancelDeleteConfirmDialog();
    }
  }

  updateTemperatureRequirement(stageId: number, payload: Record<string, unknown>): void {
    this.updateTemperatureRequirementUseCase.execute({
      cropId: this.cropId,
      stageId,
      payload
    });
  }

  updateThermalRequirement(stageId: number, payload: Record<string, unknown>): void {
    this.updateThermalRequirementUseCase.execute({
      cropId: this.cropId,
      stageId,
      payload
    });
  }

  updateSunshineRequirement(stageId: number, payload: Record<string, unknown>): void {
    this.updateSunshineRequirementUseCase.execute({
      cropId: this.cropId,
      stageId,
      payload
    });
  }

  updateNutrientRequirement(stageId: number, payload: Record<string, unknown>): void {
    this.updateNutrientRequirementUseCase.execute({
      cropId: this.cropId,
      stageId,
      payload
    });
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

    this.reorderCropStagesUseCase.execute({
      cropId: this.cropId,
      entries: updates
    });
  }

  formatOptionalNumber(value: number | null | undefined): string {
    if (value == null || !Number.isFinite(value)) {
      return this.translate.instant('crops.edit.value_missing');
    }
    return String(value);
  }

  formatCumulativeGdd(stage: CropStage): string {
    const range = stageCumulativeGddRange(this.control.formData.crop_stages, stage.order);
    if (range.gddRangeMissing) {
      return this.translate.instant('crops.edit.value_missing');
    }
    return this.translate.instant('crops.edit.stage_cumulative_gdd_range', {
      start: range.cumulativeGddStart,
      end: range.cumulativeGddEnd
    });
  }

  hasTemperatureScale(): boolean {
    return this.getTemperatureScaleRange() != null;
  }

  temperatureScaleMarkers(): TemperatureScaleMarker[] {
    const range = this.getTemperatureScaleRange();
    if (!range) {
      return [];
    }
    const toPosition = (value: number | null): number | null => {
      if (value == null || !Number.isFinite(value)) {
        return null;
      }
      return ((value - range.min) / (range.max - range.min)) * 100;
    };
    const markers: TemperatureScaleMarker[] = [];
    const addMarker = (key: TemperatureScaleMarker['key'], value: number | null) => {
      const position = toPosition(value);
      if (position != null) {
        markers.push({ key, position });
      }
    };
    addMarker('base', this.stageEditDraft.base_temperature);
    addMarker('optimal_min', this.stageEditDraft.optimal_min);
    addMarker('optimal_max', this.stageEditDraft.optimal_max);
    addMarker('max', this.stageEditDraft.max_temperature);
    return markers;
  }

  temperatureScaleBand(): TemperatureScaleBand | null {
    const range = this.getTemperatureScaleRange();
    if (!range) {
      return null;
    }
    const { optimal_min, optimal_max } = this.stageEditDraft;
    if (
      optimal_min == null ||
      optimal_max == null ||
      !Number.isFinite(optimal_min) ||
      !Number.isFinite(optimal_max)
    ) {
      return null;
    }
    const span = range.max - range.min;
    const left = ((Math.min(optimal_min, optimal_max) - range.min) / span) * 100;
    const right = ((Math.max(optimal_min, optimal_max) - range.min) / span) * 100;
    return { left, width: right - left };
  }

  private getTemperatureScaleRange(): { min: number; max: number } | null {
    const { base_temperature, optimal_min, optimal_max, max_temperature } = this.stageEditDraft;
    const values = [base_temperature, optimal_min, optimal_max, max_temperature].filter(
      (value): value is number => value != null && Number.isFinite(value)
    );
    if (values.length < 2) {
      return null;
    }
    const min = Math.min(...values);
    const max = Math.max(...values);
    if (max <= min) {
      return null;
    }
    return { min, max };
  }

  isPanelDirty(): boolean {
    const stage = this.selectedStage;
    if (!stage) {
      return false;
    }
    const temp = stage.temperature_requirement;
    const currentRequiredGdd = stage.thermal_requirement?.required_gdd ?? null;
    return (
      this.stageEditDraft.name !== stage.name ||
      this.stageEditDraft.base_temperature !== (temp?.base_temperature ?? null) ||
      this.stageEditDraft.optimal_min !== (temp?.optimal_min ?? null) ||
      this.stageEditDraft.optimal_max !== (temp?.optimal_max ?? null) ||
      this.stageEditDraft.max_temperature !== (temp?.max_temperature ?? null) ||
      this.stageEditDraft.required_gdd !== currentRequiredGdd
    );
  }

  syncDraftFromStage(stage: CropStage): void {
    this.stageEditDraft = {
      name: stage.name,
      base_temperature: stage.temperature_requirement?.base_temperature ?? null,
      optimal_min: stage.temperature_requirement?.optimal_min ?? null,
      optimal_max: stage.temperature_requirement?.optimal_max ?? null,
      max_temperature: stage.temperature_requirement?.max_temperature ?? null,
      required_gdd: stage.thermal_requirement?.required_gdd ?? null
    };
  }

  private ensureSelectedStage(): void {
    const stages = this.control.formData.crop_stages;
    const currentIds = new Set(stages.map((stage) => stage.id));
    const newStageIds = stages
      .filter((stage) => !this.knownStageIds.has(stage.id))
      .map((stage) => stage.id);
    this.knownStageIds = currentIds;

    if (stages.length === 0) {
      this.selectedStageId = null;
      this.stageEditDraft = {
        name: '',
        base_temperature: null,
        optimal_min: null,
        optimal_max: null,
        max_temperature: null,
        required_gdd: null
      };
      return;
    }

    if (newStageIds.length === 1) {
      this.selectStageImmediate(newStageIds[0]);
      return;
    }

    if (this.selectedStageId == null || !currentIds.has(this.selectedStageId)) {
      const first = sortStagesByOrder(stages)[0];
      this.selectStageImmediate(first.id);
      return;
    }

    const stage = stages.find((item) => item.id === this.selectedStageId);
    if (stage && !this.isPanelDirty()) {
      this.syncDraftFromStage(stage);
    }
  }
}
