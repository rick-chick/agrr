import { Component, OnInit, inject, ChangeDetectorRef, ViewChild, ElementRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import {
  CropStageEditView,
  CropStageEditViewState
} from './crop-stage-edit.view';
import { CropStagesFormData } from './crop-stages.view';
import { LoadCropForEditUseCase } from '../../../usecase/crops/load-crop-for-edit.usecase';
import { LoadCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/load-crop-task-schedule-blueprints.usecase';
import { DeleteCropStageUseCase } from '../../../usecase/crops/delete-crop-stage.usecase';
import { SaveCropStagePanelUseCase } from '../../../usecase/crops/save-crop-stage-panel.usecase';
import { SaveCropStageAdvancedDetailsUseCase } from '../../../usecase/crops/save-crop-stage-advanced-details.usecase';
import {
  CropStageEditPresenter,
  CROP_STAGE_EDIT_PROVIDERS
} from '../../../usecase/crops/crop-stage-edit.providers';
import { FlashMessageService } from '../../../services/flash-message.service';
import { AuthService } from '../../../services/auth.service';
import { applyPendingFlashViewEffects } from '../../../core/view-effects/pending-success-flash-view.effects';
import { parseFromPlanId } from '../../../domain/crops/parse-from-plan-id';
import {
  parsePlanWizardReturnTab,
  cropPlanWizardQueryParams,
  type PlanWizardReturnTab
} from '../../../domain/crops/plan-wizard-context';
import { parseOptionalNumber } from '../../../domain/crops/parse-optional-number';
import type { CropStage } from '../../../domain/crops/crop';
import { countLinkedTaskScheduleBlueprintsForStage } from '../../../domain/crops/stage-linked-blueprint-count';
import { MasterContextHeaderComponent } from '../master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../master-context-header/master-context-crumb';
import { MasterLoadErrorPanelComponent } from '../master-load-error-panel/master-load-error-panel.component';
import {
  UnsavedChangesDeactivatable
} from '../../../guards/unsaved-changes.guard';

interface StageEditDraft {
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

const initialFormData: CropStagesFormData = {
  name: '',
  is_reference: false,
  crop_stages: []
};

const initialControl: CropStageEditViewState = {
  loading: true,
  error: null,
  formData: initialFormData,
  taskScheduleBlueprints: [],
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  pendingResyncPanelDraft: false,
  pendingNavigateToList: false
};

@Component({
  selector: 'app-crop-stage-edit',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    TranslateModule,
    MasterContextHeaderComponent,
    MasterLoadErrorPanelComponent
  ],
  providers: [...CROP_STAGE_EDIT_PROVIDERS],
  template: `
    <main class="page-main">
      @if (control.loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (control.error) {
        <app-master-context-header [crumbs]="contextCrumbs" />
        <app-master-load-error-panel
          [errorKey]="control.error"
          [listLink]="stagesListLink"
          backLabelKey="crops.edit.stages_title"
          (retry)="reload()"
        />
      } @else if (stage; as currentStage) {
        <app-master-context-header [crumbs]="contextCrumbs" />

        <header class="page-header">
          <h1 class="page-title">
            {{ 'crops.edit.stage_page_title' | translate: { name: currentStage.name, order: currentStage.order } }}
          </h1>
          <p class="page-description">{{ 'crops.edit.stages_lead' | translate }}</p>
        </header>

        @if (!canMutateStages) {
          <div class="crop-stages__readonly-notice" role="status">
            <p>{{ 'crops.edit.reference_stages_readonly' | translate }}</p>
          </div>
        }

        <section class="form-card crop-stages-section">
          <div class="crop-stages-edit-panel">
            <div class="crop-stages-edit-panel__header">
              <div class="crop-stages-edit-panel__header-fields">
                <label class="form-card__field form-card__field--small crop-stages-edit-panel__aligned-field">
                  <span class="form-card__field-label">{{ 'crops.edit.stage_name' | translate }}</span>
                  <input
                    type="text"
                    name="panel_stage_name"
                    [readonly]="!canMutateStages"
                    [(ngModel)]="stageEditDraft.name"
                  />
                </label>
                <label class="form-card__field form-card__field--small crop-stages-edit-panel__aligned-field">
                  <span class="form-card__field-label">{{ 'crops.edit.required_gdd' | translate }}</span>
                  <input
                    type="number"
                    step="0.1"
                    name="panel_required_gdd"
                    [readonly]="!canMutateStages"
                    [placeholder]="'crops.edit.required_gdd_placeholder' | translate"
                    [(ngModel)]="stageEditDraft.required_gdd"
                  />
                </label>
              </div>
            </div>
            @if (showStageNameError()) {
              <p class="form-error crop-stages-edit-panel__name-error" role="alert">
                {{ 'crops.edit.stage_name_required' | translate }}
              </p>
            }
            <p class="form-hint crop-stages-edit-panel__header-hint">
              {{ 'crops.edit.required_gdd_help' | translate }}
            </p>

            <div class="crop-stages-edit-panel__subsection crop-stages-edit-panel__subsection--temperature">
              <h4 class="crop-stages-edit-panel__subsection-title">
                {{ 'crops.edit.temperature_section' | translate }}
              </h4>
              <div class="crop-stages-edit-panel__temperature-fields">
                <label class="form-card__field form-card__field--small crop-stages-edit-panel__aligned-field">
                  <span class="form-card__field-label">{{ 'crops.edit.base_temperature' | translate }}</span>
                  <input
                    type="number"
                    step="0.1"
                    name="panel_base_temperature"
                    [readonly]="!canMutateStages"
                    [placeholder]="'crops.edit.base_temperature_placeholder' | translate"
                    [(ngModel)]="stageEditDraft.base_temperature"
                  />
                </label>
                <label class="form-card__field form-card__field--small crop-stages-edit-panel__aligned-field">
                  <span class="form-card__field-label">{{ 'crops.edit.optimal_min' | translate }}</span>
                  <input
                    type="number"
                    step="0.1"
                    name="panel_optimal_min"
                    [readonly]="!canMutateStages"
                    [(ngModel)]="stageEditDraft.optimal_min"
                  />
                </label>
                <label class="form-card__field form-card__field--small crop-stages-edit-panel__aligned-field">
                  <span class="form-card__field-label">{{ 'crops.edit.optimal_max' | translate }}</span>
                  <input
                    type="number"
                    step="0.1"
                    name="panel_optimal_max"
                    [readonly]="!canMutateStages"
                    [(ngModel)]="stageEditDraft.optimal_max"
                  />
                </label>
                <label class="form-card__field form-card__field--small crop-stages-edit-panel__aligned-field">
                  <span class="form-card__field-label">{{ 'crops.edit.max_temperature' | translate }}</span>
                  <input
                    type="number"
                    step="0.1"
                    name="panel_max_temperature"
                    [readonly]="!canMutateStages"
                    [(ngModel)]="stageEditDraft.max_temperature"
                  />
                </label>
              </div>
              <p class="form-hint crop-stages-edit-panel__temperature-hint">
                {{ 'crops.edit.base_temperature_help' | translate }}
              </p>
            </div>

            <div class="crop-stages-edit-panel__subsection crop-stages-edit-panel__subsection--details">
              <h4 class="crop-stages-edit-panel__subsection-title">
                {{ 'crops.edit.details_section' | translate }}
              </h4>
              <div class="crop-stages-edit-panel__detail-chips">
                <button
                  type="button"
                  class="crop-stages-edit-panel__detail-chip"
                  [disabled]="!canMutateStages"
                  (click)="openTemperatureDialog()"
                >
                  {{ 'crops.edit.edit_temperature_details' | translate }}
                  <span class="crop-stages-edit-panel__detail-chip-chevron" aria-hidden="true">›</span>
                </button>
                <button
                  type="button"
                  class="crop-stages-edit-panel__detail-chip"
                  [disabled]="!canMutateStages"
                  (click)="openAdvancedDialog()"
                >
                  {{ 'crops.edit.edit_sunshine_nutrient' | translate }}
                  <span class="crop-stages-edit-panel__detail-chip-chevron" aria-hidden="true">›</span>
                </button>
              </div>
            </div>

            <div class="crop-stages-edit-panel__footer">
              @if (canMutateStages) {
                <button
                  type="button"
                  class="btn btn-primary"
                  [disabled]="!canSaveStagePanel()"
                  (click)="saveStagePanel()"
                >
                  {{ 'crops.edit.save_stage' | translate }}
                </button>
                <button type="button" class="btn btn-danger" (click)="deleteCropStage(currentStage.id)">
                  {{ 'common.delete' | translate }}
                </button>
              }
            </div>
          </div>
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
      <p class="confirm-dialog__message">{{ 'crops.edit.unsaved_confirm_message' | translate }}</p>
      <div class="confirm-dialog__actions">
        <button type="button" class="btn-secondary" (click)="cancelUnsavedConfirmDialog()">
          {{ 'common.cancel' | translate }}
        </button>
        <button type="button" class="btn-primary" (click)="confirmDiscardUnsavedLeave()">
          {{ 'common.confirm' | translate }}
        </button>
      </div>
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
  styleUrls: ['./crop-stage-edit.component.css']
})
export class CropStageEditComponent implements CropStageEditView, UnsavedChangesDeactivatable, OnInit {
  @ViewChild('deleteConfirmDialog') deleteConfirmDialogRef?: ElementRef<HTMLDialogElement>;
  @ViewChild('unsavedConfirmDialog') unsavedConfirmDialogRef?: ElementRef<HTMLDialogElement>;
  @ViewChild('temperatureDialog') temperatureDialogRef?: ElementRef<HTMLDialogElement>;
  @ViewChild('advancedDialog') advancedDialogRef?: ElementRef<HTMLDialogElement>;

  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly loadUseCase = inject(LoadCropForEditUseCase);
  private readonly loadBlueprintsUseCase = inject(LoadCropTaskScheduleBlueprintsUseCase);
  private readonly deleteCropStageUseCase = inject(DeleteCropStageUseCase);
  private readonly saveCropStagePanelUseCase = inject(SaveCropStagePanelUseCase);
  private readonly saveCropStageAdvancedDetailsUseCase = inject(SaveCropStageAdvancedDetailsUseCase);
  private readonly presenter = inject(CropStageEditPresenter);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly auth = inject(AuthService);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: CropStageEditViewState = initialControl;
  private pendingTemperatureDialogSave = false;
  private pendingAdvancedDialogSave = false;
  private pendingPanelSaveNavigate = false;
  private pendingUnsavedLeaveResolve: ((confirmed: boolean) => void) | null = null;
  private draftSyncedForStageId: number | null = null;

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
  pendingDeleteStage: CropStage | null = null;

  fromPlanId: number | null = null;
  returnTab: PlanWizardReturnTab = 'task_schedule';

  get control(): CropStageEditViewState {
    return this._control;
  }
  set control(value: CropStageEditViewState) {
    const forceResyncPanelDraft = value.pendingResyncPanelDraft;
    const shouldNavigateAfterPanelSave =
      this.pendingPanelSaveNavigate &&
      value.pendingSuccessFlash != null &&
      value.pendingErrorFlash == null;
    const shouldNavigateToList = value.pendingNavigateToList;

    const validated = this.validateStageExists({
      ...value,
      pendingResyncPanelDraft: false,
      pendingNavigateToList: false
    });

    this._control = applyPendingFlashViewEffects(validated, { flash: this.flashMessage });
    this.settlePendingDialogSaves(value);

    if (this.stage) {
      if (forceResyncPanelDraft || this.draftSyncedForStageId !== this.stage.id) {
        this.syncDraftFromStage(this.stage);
        this.draftSyncedForStageId = this.stage.id;
      }
    }

    if (shouldNavigateAfterPanelSave) {
      this.pendingPanelSaveNavigate = false;
      this.navigateToStagesList();
    } else if (shouldNavigateToList) {
      this.navigateToStagesList();
    }

    this.cdr.markForCheck();
  }

  private settlePendingDialogSaves(value: CropStageEditViewState): void {
    if (
      this.pendingTemperatureDialogSave &&
      value.pendingSuccessFlash != null &&
      value.pendingErrorFlash == null
    ) {
      this.pendingTemperatureDialogSave = false;
      this.temperatureDetailDraft = null;
      this.temperatureDialogRef?.nativeElement?.close();
    }
    if (
      this.pendingAdvancedDialogSave &&
      value.pendingSuccessFlash != null &&
      value.pendingErrorFlash == null
    ) {
      this.pendingAdvancedDialogSave = false;
      this.advancedDetailDraft = null;
      this.advancedDialogRef?.nativeElement?.close();
    }
  }

  private validateStageExists(value: CropStageEditViewState): CropStageEditViewState {
    if (value.loading || value.error || this.resolvedStageId == null) {
      return value;
    }
    const exists = value.formData.crop_stages.some((item) => item.id === this.resolvedStageId);
    if (!exists) {
      return { ...value, error: 'crops.errors.stage_not_found' };
    }
    return value;
  }

  private get resolvedCropId(): number | null {
    const raw = this.route.snapshot.paramMap.get('id');
    if (raw == null || raw === '') {
      return null;
    }
    const parsed = Number(raw);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
  }

  private get resolvedStageId(): number | null {
    const raw = this.route.snapshot.paramMap.get('stageId');
    if (raw == null || raw === '') {
      return null;
    }
    const parsed = Number(raw);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
  }

  get cropId(): number {
    return this.resolvedCropId ?? 0;
  }

  get stageId(): number {
    return this.resolvedStageId ?? 0;
  }

  get stage(): CropStage | null {
    if (this.resolvedStageId == null) {
      return null;
    }
    return this.control.formData.crop_stages.find((item) => item.id === this.resolvedStageId) ?? null;
  }

  get wizardQueryParams(): ReturnType<typeof cropPlanWizardQueryParams> | null {
    return this.fromPlanId != null
      ? cropPlanWizardQueryParams(this.fromPlanId, this.returnTab)
      : null;
  }

  get stagesListLink(): (string | number)[] {
    return ['/crops', this.cropId, 'stages'];
  }

  get contextCrumbs(): MasterContextCrumb[] {
    const crumbs: MasterContextCrumb[] = [
      { labelKey: 'crops.index.title', routerLink: ['/crops'] }
    ];
    const cropName = this.control.formData.name;
    if (cropName) {
      crumbs.push({ label: cropName, routerLink: ['/crops', this.cropId] });
    }
    crumbs.push({
      labelKey: 'crops.edit.stages_title',
      routerLink: this.stagesListLink,
      queryParams: this.wizardQueryParams
    });
    const stageName = this.stage?.name;
    if (stageName) {
      crumbs.push({ label: stageName });
    }
    return crumbs;
  }

  get canMutateStages(): boolean {
    if (this.control.formData.is_reference) {
      return this.auth.user()?.admin ?? false;
    }
    return true;
  }

  get pendingDeleteBlueprintCount(): number {
    if (!this.pendingDeleteStage) {
      return 0;
    }
    return countLinkedTaskScheduleBlueprintsForStage(
      this.pendingDeleteStage.id,
      this.control.formData.crop_stages,
      this.control.taskScheduleBlueprints
    );
  }

  hasUnsavedChanges(): boolean {
    return this.isPanelDirty();
  }

  confirmDiscardUnsavedChanges(): Promise<boolean> {
    return new Promise((resolve) => {
      this.pendingUnsavedLeaveResolve = resolve;
      this.unsavedConfirmDialogRef?.nativeElement?.showModal();
    });
  }

  confirmDiscardUnsavedLeave(): void {
    this.unsavedConfirmDialogRef?.nativeElement?.close();
    this.pendingUnsavedLeaveResolve?.(true);
    this.pendingUnsavedLeaveResolve = null;
  }

  cancelUnsavedConfirmDialog(event?: Event): void {
    event?.preventDefault();
    this.unsavedConfirmDialogRef?.nativeElement?.close();
    this.pendingUnsavedLeaveResolve?.(false);
    this.pendingUnsavedLeaveResolve = null;
  }

  onUnsavedConfirmDialogBackdropClick(event: MouseEvent): void {
    if (event.target === this.unsavedConfirmDialogRef?.nativeElement) {
      this.cancelUnsavedConfirmDialog();
    }
  }

  isStageNameValid(): boolean {
    return this.stageEditDraft.name.trim().length > 0;
  }

  showStageNameError(): boolean {
    return this.isPanelDirty() && !this.isStageNameValid();
  }

  canSaveStagePanel(): boolean {
    return this.canMutateStages && this.isPanelDirty() && this.isStageNameValid();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.fromPlanId = parseFromPlanId(this.route.snapshot.queryParamMap.get('fromPlan'));
    this.returnTab = parsePlanWizardReturnTab(this.route.snapshot.queryParamMap.get('returnTo'));
    if (this.resolvedCropId == null) {
      this.control = {
        ...initialControl,
        loading: false,
        error: 'crops.errors.invalid_id'
      };
      return;
    }
    if (this.resolvedStageId == null) {
      this.control = {
        ...initialControl,
        loading: false,
        error: 'crops.errors.stage_not_found'
      };
      return;
    }
    this.loadCrop();
  }

  reload(): void {
    this.draftSyncedForStageId = null;
    this.control = { ...initialControl };
    this.loadCrop();
  }

  private loadCrop(): void {
    this.loadUseCase.execute({ cropId: this.cropId });
    this.loadBlueprintsUseCase.execute({ cropId: this.cropId });
  }

  reloadTaskScheduleBlueprints(): void {
    if (this.resolvedCropId == null) {
      return;
    }
    this.loadBlueprintsUseCase.execute({ cropId: this.cropId });
  }

  private navigateToStagesList(): void {
    void this.router.navigate(this.stagesListLink, {
      queryParams: this.wizardQueryParams ?? undefined
    });
  }

  saveStagePanel(): void {
    const currentStage = this.stage;
    if (!currentStage || !this.canMutateStages) {
      return;
    }

    if (!this.isStageNameValid()) {
      return;
    }

    if (!this.isPanelDirty()) {
      this.flashMessage.show({ type: 'info', text: 'crops.flash.stage_panel_no_changes' });
      return;
    }

    const stagePatch =
      this.stageEditDraft.name !== currentStage.name ? { name: this.stageEditDraft.name } : undefined;

    const temp = currentStage.temperature_requirement;
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

    const currentRequiredGdd = currentStage.thermal_requirement?.required_gdd ?? null;
    const thermalPatch =
      this.stageEditDraft.required_gdd !== currentRequiredGdd
        ? { required_gdd: this.stageEditDraft.required_gdd }
        : undefined;

    this.pendingPanelSaveNavigate = true;
    this.saveCropStagePanelUseCase.execute({
      cropId: this.cropId,
      stageId: currentStage.id,
      stagePatch,
      temperaturePatch: Object.keys(temperaturePatch).length > 0 ? temperaturePatch : undefined,
      thermalPatch
    });
  }

  openTemperatureDialog(): void {
    if (!this.canMutateStages) {
      return;
    }
    const currentStage = this.stage;
    if (!currentStage) {
      return;
    }
    const temp = currentStage.temperature_requirement;
    this.temperatureDetailDraft = {
      low_stress_threshold: temp?.low_stress_threshold ?? null,
      high_stress_threshold: temp?.high_stress_threshold ?? null,
      frost_threshold: temp?.frost_threshold ?? null
    };
    this.temperatureDialogRef?.nativeElement?.showModal();
  }

  saveTemperatureDialog(): void {
    const currentStage = this.stage;
    if (!currentStage || !this.temperatureDetailDraft) {
      return;
    }
    const temp = currentStage.temperature_requirement;
    const draft = this.temperatureDetailDraft;
    const temperaturePatch: {
      low_stress_threshold?: number | null;
      high_stress_threshold?: number | null;
      frost_threshold?: number | null;
    } = {};
    if (draft.low_stress_threshold !== (temp?.low_stress_threshold ?? null)) {
      temperaturePatch.low_stress_threshold = draft.low_stress_threshold;
    }
    if (draft.high_stress_threshold !== (temp?.high_stress_threshold ?? null)) {
      temperaturePatch.high_stress_threshold = draft.high_stress_threshold;
    }
    if (draft.frost_threshold !== (temp?.frost_threshold ?? null)) {
      temperaturePatch.frost_threshold = draft.frost_threshold;
    }

    if (Object.keys(temperaturePatch).length === 0) {
      this.temperatureDetailDraft = null;
      this.temperatureDialogRef?.nativeElement?.close();
      return;
    }

    this.pendingTemperatureDialogSave = true;
    this.saveCropStagePanelUseCase.execute({
      cropId: this.cropId,
      stageId: currentStage.id,
      temperaturePatch
    });
  }

  cancelTemperatureDialog(event?: Event): void {
    event?.preventDefault();
    this.pendingTemperatureDialogSave = false;
    this.temperatureDetailDraft = null;
    this.temperatureDialogRef?.nativeElement?.close();
  }

  onTemperatureDialogBackdropClick(event: MouseEvent): void {
    if (event.target === this.temperatureDialogRef?.nativeElement) {
      this.cancelTemperatureDialog();
    }
  }

  openAdvancedDialog(): void {
    if (!this.canMutateStages) {
      return;
    }
    const currentStage = this.stage;
    if (!currentStage) {
      return;
    }
    const sunshine = currentStage.sunshine_requirement;
    const nutrient = currentStage.nutrient_requirement;
    const temp = currentStage.temperature_requirement;
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
    const currentStage = this.stage;
    if (!currentStage || !this.advancedDetailDraft) {
      return;
    }
    const draft = this.advancedDetailDraft;
    const sunshine = currentStage.sunshine_requirement;
    const nutrient = currentStage.nutrient_requirement;
    const temperature = currentStage.temperature_requirement;

    const sunshinePatch: {
      minimum_sunshine_hours?: number | null;
      target_sunshine_hours?: number | null;
    } = {};
    if (draft.minimum_sunshine_hours !== (sunshine?.minimum_sunshine_hours ?? null)) {
      sunshinePatch.minimum_sunshine_hours = draft.minimum_sunshine_hours;
    }
    if (draft.target_sunshine_hours !== (sunshine?.target_sunshine_hours ?? null)) {
      sunshinePatch.target_sunshine_hours = draft.target_sunshine_hours;
    }

    const nutrientPatch: {
      daily_uptake_n?: number | null;
      daily_uptake_p?: number | null;
      daily_uptake_k?: number | null;
      region?: string | null;
    } = {};
    if (draft.daily_uptake_n !== (nutrient?.daily_uptake_n ?? null)) {
      nutrientPatch.daily_uptake_n = draft.daily_uptake_n;
    }
    if (draft.daily_uptake_p !== (nutrient?.daily_uptake_p ?? null)) {
      nutrientPatch.daily_uptake_p = draft.daily_uptake_p;
    }
    if (draft.daily_uptake_k !== (nutrient?.daily_uptake_k ?? null)) {
      nutrientPatch.daily_uptake_k = draft.daily_uptake_k;
    }
    if (draft.region !== (nutrient?.region ?? null)) {
      nutrientPatch.region = draft.region;
    }

    const temperaturePatch: {
      sterility_risk_threshold?: number | null;
    } = {};
    if (draft.sterility_risk_threshold !== (temperature?.sterility_risk_threshold ?? null)) {
      temperaturePatch.sterility_risk_threshold = draft.sterility_risk_threshold;
    }

    if (
      Object.keys(sunshinePatch).length === 0 &&
      Object.keys(nutrientPatch).length === 0 &&
      Object.keys(temperaturePatch).length === 0
    ) {
      this.advancedDetailDraft = null;
      this.advancedDialogRef?.nativeElement?.close();
      return;
    }

    this.pendingAdvancedDialogSave = true;
    this.saveCropStageAdvancedDetailsUseCase.execute({
      cropId: this.cropId,
      stageId: currentStage.id,
      sunshinePatch: Object.keys(sunshinePatch).length > 0 ? sunshinePatch : undefined,
      nutrientPatch: Object.keys(nutrientPatch).length > 0 ? nutrientPatch : undefined,
      temperaturePatch: Object.keys(temperaturePatch).length > 0 ? temperaturePatch : undefined
    });
  }

  cancelAdvancedDialog(event?: Event): void {
    event?.preventDefault();
    this.pendingAdvancedDialogSave = false;
    this.advancedDetailDraft = null;
    this.advancedDialogRef?.nativeElement?.close();
  }

  onAdvancedDialogBackdropClick(event: MouseEvent): void {
    if (event.target === this.advancedDialogRef?.nativeElement) {
      this.cancelAdvancedDialog();
    }
  }

  deleteCropStage(stageId: number): void {
    if (!this.canMutateStages) {
      return;
    }
    const currentStage = this.control.formData.crop_stages.find((item) => item.id === stageId);
    if (!currentStage) {
      return;
    }
    this.openDeleteConfirmDialog(currentStage);
  }

  private openDeleteConfirmDialog(stage: CropStage): void {
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

  isPanelDirty(): boolean {
    const currentStage = this.stage;
    if (!currentStage) {
      return false;
    }
    const temp = currentStage.temperature_requirement;
    const currentRequiredGdd = parseOptionalNumber(currentStage.thermal_requirement?.required_gdd);
    return (
      this.stageEditDraft.name !== currentStage.name ||
      this.stageEditDraft.base_temperature !== parseOptionalNumber(temp?.base_temperature) ||
      this.stageEditDraft.optimal_min !== parseOptionalNumber(temp?.optimal_min) ||
      this.stageEditDraft.optimal_max !== parseOptionalNumber(temp?.optimal_max) ||
      this.stageEditDraft.max_temperature !== parseOptionalNumber(temp?.max_temperature) ||
      this.stageEditDraft.required_gdd !== currentRequiredGdd
    );
  }

  syncDraftFromStage(stage: CropStage): void {
    this.stageEditDraft = {
      name: stage.name,
      base_temperature: parseOptionalNumber(stage.temperature_requirement?.base_temperature),
      optimal_min: parseOptionalNumber(stage.temperature_requirement?.optimal_min),
      optimal_max: parseOptionalNumber(stage.temperature_requirement?.optimal_max),
      max_temperature: parseOptionalNumber(stage.temperature_requirement?.max_temperature),
      required_gdd: parseOptionalNumber(stage.thermal_requirement?.required_gdd)
    };
  }
}
