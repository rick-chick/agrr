import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { CdkDragDrop, DragDropModule } from '@angular/cdk/drag-drop';
import { CropStagesView, CropStagesViewState, CropStagesFormData } from './crop-stages.view';
import { LoadCropForEditUseCase } from '../../../usecase/crops/load-crop-for-edit.usecase';
import { CreateCropStageUseCase } from '../../../usecase/crops/create-crop-stage.usecase';
import { ReorderCropStagesUseCase } from '../../../usecase/crops/reorder-crop-stages.usecase';
import { LoadCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/load-crop-task-schedule-blueprints.usecase';
import {
  CropStagesPresenter,
  CROP_STAGES_PROVIDERS
} from '../../../usecase/crops/crop-stages.providers';
import { FlashMessageService } from '../../../services/flash-message.service';
import { AuthService } from '../../../services/auth.service';
import { applyPendingFlashViewEffects } from '../../../core/view-effects/pending-success-flash-view.effects';
import { parseFromPlanId } from '../../../domain/crops/parse-from-plan-id';
import {
  parsePlanWizardReturnTab,
  planWizardReturnPath,
  cropPlanWizardQueryParams,
  type PlanWizardReturnTab
} from '../../../domain/crops/plan-wizard-context';
import { stageCumulativeGddRange } from '../../../domain/crops/stage-cumulative-gdd';
import {
  findDuplicateStageOrders,
  reorderStagesByIndex,
  renumberStagesSequentially,
  sortStagesByOrder
} from '../../../domain/crops/crop-stage-order';
import type { CropStage } from '../../../domain/crops/crop';
import { MasterContextHeaderComponent } from '../master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../master-context-header/master-context-crumb';
import { MasterLoadErrorPanelComponent } from '../master-load-error-panel/master-load-error-panel.component';
import { withCropStagesDisplayState } from '../../../adapters/crops/crop-stages-display-state';
import { defaultBlueprintReadiness } from '../../../domain/crops/blueprint-generation-readiness';

const initialFormData: CropStagesFormData = {
  name: '',
  is_reference: false,
  crop_stages: []
};

const initialControl: CropStagesViewState = {
  loading: true,
  error: null,
  formData: initialFormData,
  taskScheduleBlueprints: [],
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  pendingReorderCropStagesSnapshot: null,
  pendingResyncPanelDraft: false,
  blueprintReadiness: defaultBlueprintReadiness(),
  stageRequirementGaps: [],
  showBlueprintReadinessChecklist: false,
  showNextStepCta: false
};

@Component({
  selector: 'app-crop-stages',
  standalone: true,
  imports: [
    CommonModule,
    RouterLink,
    TranslateModule,
    MasterContextHeaderComponent,
    MasterLoadErrorPanelComponent,
    DragDropModule
  ],
  providers: [...CROP_STAGES_PROVIDERS],
  template: `
    <main class="page-main">
      @if (control.loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (control.error) {
        <app-master-context-header
          [crumbs]="contextCrumbs"
          [forwardRouterLink]="control.showNextStepCta ? ['/crops', cropId, 'task_schedule_blueprints'] : null"
          [forwardQueryParams]="control.showNextStepCta ? wizardQueryParams : null"
          forwardLabelKey="crops.show.blueprint_readiness.stages_next_step_action"
        />
        <app-master-load-error-panel
          [errorKey]="control.error"
          [listLink]="['/crops']"
          backLabelKey="crops.index.title"
          (retry)="reload()"
        />
      } @else {
        <app-master-context-header
          [crumbs]="contextCrumbs"
          [forwardRouterLink]="control.showNextStepCta ? ['/crops', cropId, 'task_schedule_blueprints'] : null"
          [forwardQueryParams]="control.showNextStepCta ? wizardQueryParams : null"
          forwardLabelKey="crops.show.blueprint_readiness.stages_next_step_action"
        />
        @if (fromPlanId) {
          <div class="crop-blueprints__plan-wizard-banner" role="status">
            <p class="crop-blueprints__plan-wizard-banner-title">
              {{ 'crops.show.from_plan_wizard_title' | translate }}
            </p>
            <p class="crop-blueprints__plan-wizard-banner-lead">
              {{ 'crops.show.from_plan_stages_wizard_lead' | translate }}
            </p>
            @if (control.stageRequirementGaps.length > 0) {
              <ul class="crop-stages__plan-wizard-gaps" role="list">
                @for (gap of control.stageRequirementGaps; track gap.stageId) {
                  <li>
                    @if (gap.missingBaseTemperature) {
                      <span>{{
                        'crops.show.blueprint_readiness.stages_page_gap_base_temperature'
                          | translate: { stageName: gap.stageName }
                      }}</span>
                    }
                    @if (gap.missingRequiredGdd) {
                      <span>{{
                        'crops.show.blueprint_readiness.stages_page_gap_required_gdd'
                          | translate: { stageName: gap.stageName }
                      }}</span>
                    }
                  </li>
                }
              </ul>
            }
            <a [routerLink]="planReturnPath" class="btn-secondary crop-stages__return-to-plan">
              {{ 'crops.show.return_to_plan' | translate }}
            </a>
          </div>
        }

        <header class="page-header">
          <h1 class="page-title">{{ control.formData.name }}</h1>
          <p class="page-description">{{ 'crops.edit.stages_lead' | translate }}</p>
        </header>

        @if (!canMutateStages) {
          <div class="crop-stages__readonly-notice" role="status">
            <p>{{ 'crops.edit.reference_stages_readonly' | translate }}</p>
          </div>
        }

        @if (control.showBlueprintReadinessChecklist) {
          <div class="blueprint-readiness" role="status">
            <p class="blueprint-readiness__title">
              {{ 'crops.show.blueprint_readiness.detail_title' | translate }}
            </p>
            <ul class="blueprint-readiness__list">
              @for (gap of control.stageRequirementGaps; track gap.stageId) {
                <li>
                  @if (gap.missingBaseTemperature) {
                    <span>{{
                      'crops.show.blueprint_readiness.stages_page_gap_base_temperature'
                        | translate: { stageName: gap.stageName }
                    }}</span>
                  }
                  @if (gap.missingRequiredGdd) {
                    <span>{{
                      'crops.show.blueprint_readiness.stages_page_gap_required_gdd'
                        | translate: { stageName: gap.stageName }
                    }}</span>
                  }
                </li>
              }
            </ul>
          </div>
        }

        <section class="form-card crop-stages-section" aria-labelledby="stages-heading">
          <h2 id="stages-heading" class="crop-stages-section__title">{{ 'crops.edit.stages_list_heading' | translate }}</h2>

          @if (duplicateStageOrders.length > 0) {
            <div class="crop-stages-order-warning" role="alert">
              <p class="crop-stages-order-warning__message">
                {{
                  'crops.edit.stage_order_duplicate'
                    | translate: { orders: duplicateStageOrders.join(', ') }
                }}
              </p>
              <p class="crop-stages-order-warning__hint">
                {{ 'crops.edit.stage_order_duplicate_hint' | translate }}
              </p>
              <button
                type="button"
                class="btn btn-secondary crop-stages-order-warning__renumber"
                [disabled]="!canMutateStages"
                (click)="renumberDuplicateStageOrders()"
              >
                {{ 'crops.edit.stage_order_renumber' | translate }}
              </button>
            </div>
          }

          @if (control.formData.crop_stages.length === 0) {
            <div class="crop-stages-empty">
              <p class="crop-stages-empty__lead">{{ 'crops.edit.stages_empty_lead' | translate }}</p>
              <p class="crop-stages-empty__description">{{ 'crops.show.no_stages_description' | translate }}</p>
              @if (canMutateStages) {
                <button type="button" class="btn btn-primary crop-stages-empty__cta" (click)="addCropStage()">
                  {{ 'crops.edit.add_stage' | translate }}
                </button>
              }
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
                    [cdkDragDisabled]="!canMutateStages"
                    [cdkDragData]="stage"
                    (click)="navigateToStageEdit(stage.id)"
                  >
                    <td class="crop-stages-table__drag" cdkDragHandle (click)="$event.stopPropagation()">
                      @if (canMutateStages) {
                        <span class="crop-stages-table__drag-icon" aria-hidden="true">≡</span>
                      }
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
                    @if (canMutateStages) {
                      <button type="button" class="crop-stages-table__add-button" (click)="addCropStage()">
                        {{ 'crops.edit.add_stage' | translate }}
                      </button>
                    }
                  </td>
                </tr>
              </tbody>
            </table>
          }
        </section>
      }
    </main>
  `,
  styleUrls: ['./crop-stages.component.css', './_crop-blueprint-shared.css']
})
export class CropStagesComponent implements CropStagesView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly loadUseCase = inject(LoadCropForEditUseCase);
  private readonly loadBlueprintsUseCase = inject(LoadCropTaskScheduleBlueprintsUseCase);
  private readonly createCropStageUseCase = inject(CreateCropStageUseCase);
  private readonly reorderCropStagesUseCase = inject(ReorderCropStagesUseCase);
  private readonly presenter = inject(CropStagesPresenter);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly auth = inject(AuthService);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly translate = inject(TranslateService);

  private _control: CropStagesViewState = initialControl;
  private knownStageIds = new Set<number>();
  private awaitingCreateNavigation = false;

  get control(): CropStagesViewState {
    return this._control;
  }
  set control(value: CropStagesViewState) {
    const previousStages = this._control.formData.crop_stages;
    this._control = withCropStagesDisplayState(
      applyPendingFlashViewEffects(value, { flash: this.flashMessage })
    );
    const stages = value.formData.crop_stages;
    const stagesChanged = previousStages !== stages;
    if (stagesChanged) {
      const newStageIds = stages
        .filter((stage) => !this.knownStageIds.has(stage.id))
        .map((stage) => stage.id);
      this.knownStageIds = new Set(stages.map((stage) => stage.id));
      if (this.awaitingCreateNavigation && newStageIds.length === 1) {
        this.awaitingCreateNavigation = false;
        const stageId = newStageIds[0];
        queueMicrotask(() => this.navigateToStageEdit(stageId));
      }
    }
    this.cdr.markForCheck();
  }

  private get resolvedCropId(): number | null {
    const raw = this.route.snapshot.paramMap.get('id');
    if (raw == null || raw === '') {
      return null;
    }
    const parsed = Number(raw);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
  }

  get cropId(): number {
    return this.resolvedCropId ?? 0;
  }

  fromPlanId: number | null = null;
  returnTab: PlanWizardReturnTab = 'task_schedule';

  get planReturnPath(): (string | number)[] {
    return this.fromPlanId != null ? planWizardReturnPath(this.fromPlanId, this.returnTab) : [];
  }

  get wizardQueryParams(): ReturnType<typeof cropPlanWizardQueryParams> | null {
    return this.fromPlanId != null
      ? cropPlanWizardQueryParams(this.fromPlanId, this.returnTab)
      : null;
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

  get canMutateStages(): boolean {
    if (this.control.formData.is_reference) {
      return this.auth.user()?.admin ?? false;
    }
    return true;
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
    this.loadCrop();
  }

  reload(): void {
    this.control = { ...initialControl };
    this.knownStageIds = new Set();
    this.awaitingCreateNavigation = false;
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

  navigateToStageEdit(stageId: number): void {
    this.router.navigate(['/crops', this.cropId, 'stages', stageId, 'edit'], {
      queryParams: this.wizardQueryParams ?? undefined
    });
  }

  addCropStage(): void {
    if (!this.canMutateStages) {
      return;
    }
    const nextOrder = Math.max(0, ...this.control.formData.crop_stages.map((s) => s.order)) + 1;
    const defaultStageName = this.translate.instant('crops.stage.default_name', { order: nextOrder });
    this.awaitingCreateNavigation = true;
    this.createCropStageUseCase.execute({
      cropId: this.cropId,
      payload: {
        name: defaultStageName,
        order: nextOrder
      }
    });
  }

  onStageDropped(event: CdkDragDrop<CropStage[]>): void {
    if (!this.canMutateStages) {
      return;
    }
    const { stages, updates } = reorderStagesByIndex(
      this.control.formData.crop_stages,
      event.previousIndex,
      event.currentIndex
    );
    this.persistStageReorder(stages, updates);
  }

  renumberDuplicateStageOrders(): void {
    if (!this.canMutateStages) {
      return;
    }
    const { stages, updates } = renumberStagesSequentially(this.control.formData.crop_stages);
    this.persistStageReorder(stages, updates);
  }

  private persistStageReorder(
    stages: CropStage[],
    updates: Array<{ id: number; order: number }>
  ): void {
    if (updates.length === 0) {
      return;
    }

    this.control = {
      ...this.control,
      pendingReorderCropStagesSnapshot: [...this.control.formData.crop_stages],
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
      return this.translate.instant('crops.edit.stage_cumulative_gdd_missing');
    }
    return this.translate.instant('crops.edit.stage_cumulative_gdd_range', {
      start: range.cumulativeGddStart,
      end: range.cumulativeGddEnd
    });
  }
}
