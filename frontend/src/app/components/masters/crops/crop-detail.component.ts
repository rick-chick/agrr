import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { CdkDragDrop, DragDropModule } from '@angular/cdk/drag-drop';
import { CropDetailView, CropDetailViewState } from './crop-detail.view';
import { LoadCropDetailUseCase } from '../../../usecase/crops/load-crop-detail.usecase';
import { DeleteCropUseCase } from '../../../usecase/crops/delete-crop.usecase';
import { LoadAgriculturalTaskListUseCase } from '../../../usecase/agricultural-tasks/load-agricultural-task-list.usecase';
import { LoadCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/load-crop-task-schedule-blueprints.usecase';
import { CreateCropTaskScheduleBlueprintUseCase } from '../../../usecase/crops/create-crop-task-schedule-blueprint.usecase';
import { RegenerateCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/regenerate-crop-task-schedule-blueprints.usecase';
import { UpdateCropTaskScheduleBlueprintUseCase } from '../../../usecase/crops/update-crop-task-schedule-blueprint.usecase';
import { DeleteCropTaskScheduleBlueprintUseCase } from '../../../usecase/crops/delete-crop-task-schedule-blueprint.usecase';
import {
  CropDetailPresenter,
  CROP_DETAIL_PROVIDERS
} from '../../../usecase/crops/crop-detail.providers';
import { UndoToastService } from '../../../services/undo-toast.service';
import { applyPendingUndoToastViewEffects } from '../../../core/view-effects/pending-undo-toast-view.effects';
import { FlashMessageService } from '../../../services/flash-message.service';
import { applyPendingFlashViewEffects } from '../../../core/view-effects/pending-success-flash-view.effects';
import { formatIsoDateTimeForDisplay } from '../../../core/format-display-date';
import { BlueprintStageLane } from '../../../domain/crops/blueprint-stage-grouping';
import { CropTaskScheduleBlueprint } from '../../../domain/crops/crop-task-schedule-blueprint';
import { defaultBlueprintReadiness } from '../../../domain/crops/blueprint-generation-readiness';
import { parseFromPlanId } from '../../../domain/crops/parse-from-plan-id';
import { withCropDetailDisplayState } from '../../../adapters/crops/crop-detail-presenter.helpers';

const initialControl: CropDetailViewState = {
  loading: true,
  error: null,
  crop: null,
  pendingUndoToast: null,
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  fromPlanId: null,
  agriculturalTasksLoading: true,
  agriculturalTasks: [],
  unassociatedAgriculturalTasks: [],
  blueprintsLoading: true,
  blueprints: [],
  blueprintsRegenerating: false,
  blueprintSavingId: null,
  blueprintGddDrafts: {},
  blueprintStageLanes: [],
  blueprintRegenerateError: null,
  selectedBlueprintStageOrder: null,
  selectedBlueprintAgriculturalTaskId: null,
  blueprintCreateGddTrigger: null,
  blueprintCreating: false,
  blueprintReadiness: defaultBlueprintReadiness(),
  canRegenerateBlueprints: false,
  canCreateBlueprint: false,
  blueprintStageNameForCreate: null,
  showBlueprintReadinessChecklist: false,
  blueprintSectionDescriptionKey: 'crops.show.task_schedule_blueprints_description_empty_html',
  showBlueprintEmptyState: true,
  showBlueprintRegenerateRetry: false
};

@Component({
  selector: 'app-crop-detail',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, TranslateModule, DragDropModule],
  providers: [...CROP_DETAIL_PROVIDERS],
  template: `
    <main class="page-main">
      @if (control.loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (control.error) {
        <p class="master-loading master-error">{{ control.error }}</p>
      } @else if (control.crop) {
        @if (control.fromPlanId) {
          <div class="crop-detail__plan-wizard-banner" role="status">
            <p class="crop-detail__plan-wizard-banner-title">
              {{ 'crops.show.from_plan_wizard_title' | translate }}
            </p>
            <p class="crop-detail__plan-wizard-banner-lead">
              {{ 'crops.show.from_plan_wizard_lead' | translate }}
            </p>
          </div>
        }
        <section class="detail-card" aria-labelledby="detail-heading">
          <h1 id="detail-heading" class="detail-card__title">{{ control.crop.name }}</h1>
          <dl class="detail-card__list">
            <div class="detail-row">
              <dt class="detail-row__term">{{ 'crops.show.name' | translate }}</dt>
              <dd class="detail-row__value">{{ control.crop.name }}</dd>
            </div>
            @if (control.crop.variety) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'crops.show.variety' | translate }}</dt>
                <dd class="detail-row__value">{{ control.crop.variety }}</dd>
              </div>
            }
            @if (control.crop.area_per_unit != null) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'crops.show.area_per_unit' | translate }}</dt>
                <dd class="detail-row__value">{{ control.crop.area_per_unit }} {{ 'crops.show.area_unit' | translate }}</dd>
              </div>
            }
            @if (control.crop.revenue_per_area != null) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'crops.show.revenue_per_area' | translate }}</dt>
                <dd class="detail-row__value">{{ control.crop.revenue_per_area }} {{ 'crops.show.revenue_unit' | translate }}</dd>
              </div>
            }
            @if (control.crop.groups.length) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'crops.show.groups' | translate }}</dt>
                <dd class="detail-row__value">{{ control.crop.groups.join(', ') }}</dd>
              </div>
            }
            @if (control.crop.region) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'crops.show.region' | translate }}</dt>
                <dd class="detail-row__value">{{ 'crops.form.region_' + control.crop.region | translate }}</dd>
              </div>
            }
            @if (control.crop.created_at) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'crops.show.created_at' | translate }}</dt>
                <dd class="detail-row__value">{{ displayDateTime(control.crop.created_at) }}</dd>
              </div>
            }
            @if (control.crop.updated_at) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'crops.show.updated_at' | translate }}</dt>
                <dd class="detail-row__value">{{ displayDateTime(control.crop.updated_at) }}</dd>
              </div>
            }
          </dl>
          <div class="detail-card__actions">
            <a [routerLink]="['/crops', control.crop.id, 'edit']" class="btn-primary">{{ 'common.edit' | translate }}</a>
            @if (control.fromPlanId) {
              <a [routerLink]="['/plans', control.fromPlanId, 'work']" class="btn-secondary">{{ 'crops.show.return_to_plan' | translate }}</a>
            }
            <a [routerLink]="['/crops']" class="btn-secondary">{{ 'common.back' | translate }}</a>
            <button type="button" class="btn-danger" (click)="deleteCrop()">{{ 'common.delete' | translate }}</button>
          </div>
        </section>

        @if (control.crop.crop_stages?.length) {
          <section class="section-card" aria-labelledby="stages-heading">
            <h2 id="stages-heading" class="section-title">{{ 'crops.show.stages_title' | translate }}</h2>
            <div class="stages-grid">
              @for (stage of control.crop.crop_stages; track stage.id) {
                <div class="stage-card">
                  <h3 class="stage-card__title">{{ stage.name }}</h3>
                  <div class="stage-details">
                    @if (stage.thermal_requirement) {
                      <p><strong>{{ 'crops.show.required_gdd' | translate }}:</strong>
                        {{ stage.thermal_requirement.required_gdd }} {{ 'crops.show.gdd_unit' | translate }}</p>
                    }
                    @if (stage.temperature_requirement) {
                      <p><strong>{{ 'crops.show.optimal_temperature' | translate }}:</strong>
                        {{ stage.temperature_requirement.optimal_min }}{{ 'crops.show.celsius_unit' | translate }}
                        - {{ stage.temperature_requirement.optimal_max }}{{ 'crops.show.celsius_unit' | translate }}</p>
                    }
                  </div>
                </div>
              }
            </div>
          </section>
        }

        <section class="section-card" aria-labelledby="blueprints-heading">
          <div class="section-card__header-actions crop-detail__blueprints-header">
            <h2 id="blueprints-heading" class="section-title">
              {{ 'crops.show.task_schedule_blueprints_title' | translate }}
            </h2>
          </div>
          <p
            class="section-card__description"
            [innerHTML]="control.blueprintSectionDescriptionKey | translate"
          ></p>

          @if (control.showBlueprintReadinessChecklist) {
            <div class="blueprint-readiness" role="status">
              <p class="blueprint-readiness__title">{{ 'crops.show.blueprint_readiness.title' | translate }}</p>
              <ul class="blueprint-readiness__list">
                <li [class.blueprint-readiness__item--ok]="control.blueprintReadiness.blueprintsReady">
                  @if (control.blueprintReadiness.blueprintsReady) {
                    <span>{{ 'crops.show.blueprint_readiness.blueprints_ready' | translate }}</span>
                  } @else {
                    <span>{{ 'crops.show.blueprint_readiness.blueprints_missing' | translate }}</span>
                    <a href="#blueprints-heading" class="blueprint-readiness__link">
                      {{ 'crops.show.blueprint_readiness.blueprints_action' | translate }}
                    </a>
                  }
                </li>
                <li [class.blueprint-readiness__item--ok]="control.blueprintReadiness.stageRequirementsReady">
                  @if (control.blueprintReadiness.stageRequirementsReady) {
                    <span>{{ 'crops.show.blueprint_readiness.stages_ready' | translate }}</span>
                  } @else {
                    <span>{{ 'crops.show.blueprint_readiness.stages_missing' | translate }}</span>
                    <a [routerLink]="['/crops', control.crop.id, 'edit']" class="blueprint-readiness__link">
                      {{ 'crops.show.blueprint_readiness.stages_action' | translate }}
                    </a>
                  }
                </li>
              </ul>
            </div>
          }

          @if (control.blueprintRegenerateError) {
            <div class="page-alert-error blueprint-regenerate-error" role="alert">
              <p>{{ control.blueprintRegenerateError | translate }}</p>
              @if (!control.blueprintReadiness.blueprintsReady) {
                <p>
                  <a href="#blueprints-heading" class="blueprint-readiness__link">
                    {{ 'crops.show.blueprint_readiness.blueprints_action' | translate }}
                  </a>
                </p>
              }
              @if (!control.blueprintReadiness.stageRequirementsReady) {
                <p>
                  <a [routerLink]="['/crops', control.crop.id, 'edit']" class="blueprint-readiness__link">
                    {{ 'crops.show.blueprint_readiness.stages_action' | translate }}
                  </a>
                </p>
              }
              @if (control.showBlueprintRegenerateRetry) {
                <p>
                  <button
                    type="button"
                    class="btn-secondary"
                    [disabled]="control.blueprintsRegenerating"
                    (click)="regenerateBlueprints()"
                  >
                    {{
                      (control.blueprintsRegenerating
                        ? 'common.loading'
                        : 'crops.show.blueprint_errors.retry_action')
                        | translate
                    }}
                  </button>
                </p>
              }
            </div>
          }

          @if (control.blueprintsLoading) {
            <p class="master-loading">{{ 'common.loading' | translate }}</p>
          } @else if (control.showBlueprintEmptyState) {
            <p>{{ 'crops.show.no_task_schedule_blueprints' | translate }}</p>
          } @else {
            @if (control.crop?.crop_stages?.length) {
              <div
                class="blueprint-stage-board"
                role="list"
                cdkDropListGroup
                [attr.aria-label]="'crops.show.blueprint_stage_lane.board_label' | translate"
              >
                <p class="blueprint-stage-board__keyboard-hint sr-only">
                  {{ 'crops.show.blueprint_stage_lane.keyboard_hint' | translate }}
                </p>
                @for (lane of control.blueprintStageLanes; track blueprintLaneId(lane)) {
                  <div class="blueprint-stage-lane" role="listitem">
                    <div class="blueprint-stage-lane__label">
                      @if (lane.stageOrder == null) {
                        {{ 'crops.show.blueprint_stage_lane.unassigned' | translate }}
                      } @else {
                        {{ lane.stageName }}
                      }
                    </div>
                    <div
                      class="blueprint-stage-lane__cards"
                      cdkDropList
                      cdkDropListOrientation="horizontal"
                      [id]="blueprintLaneId(lane)"
                      [cdkDropListData]="lane.blueprints"
                      (cdkDropListDropped)="onBlueprintDropped($event, lane.stageOrder)"
                    >
                      @for (blueprint of lane.blueprints; track blueprint.id) {
                        <article
                          class="item-card blueprint-card"
                          cdkDrag
                          [cdkDragData]="blueprint"
                          [cdkDragDisabled]="control.blueprintSavingId === blueprint.id"
                        >
                          <ng-container
                            *ngTemplateOutlet="blueprintCardBody; context: { $implicit: blueprint }"
                          />
                        </article>
                      }
                    </div>
                  </div>
                }
              </div>
            } @else {
              <ul class="card-list" role="list">
                @for (blueprint of control.blueprints; track blueprint.id) {
                  <li class="card-list__item">
                    <article class="item-card blueprint-card">
                      <ng-container
                        *ngTemplateOutlet="blueprintCardBody; context: { $implicit: blueprint }"
                      />
                    </article>
                  </li>
                }
              </ul>
            }

            <ng-template #blueprintCardBody let-blueprint>
              <div class="blueprint-card__header">
                <span class="item-card__title">
                  @if (blueprint.agricultural_task?.name || blueprint.name) {
                    {{ blueprint.agricultural_task?.name || blueprint.name }}
                  } @else {
                    {{ 'crops.show.unnamed_blueprint' | translate }}
                  }
                </span>
                <button
                  type="button"
                  class="crop-detail__card-remove blueprint-card__remove"
                  (click)="deleteBlueprint(blueprint.id)"
                  [attr.aria-label]="'crops.show.delete_blueprint' | translate"
                >
                  {{ 'common.delete' | translate }}
                </button>
              </div>
              <div class="blueprint-card__fields blueprint-card__fields--gdd-only">
                <label class="blueprint-card__field blueprint-card__gdd" [attr.for]="'gdd-' + blueprint.id">
                  <span class="blueprint-card__field-label">
                    {{ 'crops.show.gdd_trigger' | translate }}
                  </span>
                  <span class="crop-detail__template-add-input-wrap">
                    <input
                      [id]="'gdd-' + blueprint.id"
                      type="number"
                      step="0.01"
                      min="0"
                      class="crop-detail__template-add-input blueprint-card__input"
                      [ngModel]="control.blueprintGddDrafts[blueprint.id]"
                      (ngModelChange)="onGddDraftChange(blueprint.id, $event)"
                      (change)="saveBlueprintGdd(blueprint.id)"
                      [disabled]="control.blueprintSavingId === blueprint.id"
                      [attr.placeholder]="
                        blueprint.gdd_trigger == null
                          ? ('crops.show.gdd_trigger_placeholder' | translate)
                          : null
                      "
                    />
                    <span class="crop-detail__template-add-input-unit" aria-hidden="true">
                      {{ 'crops.show.gdd_unit' | translate }}
                    </span>
                  </span>
                </label>
              </div>
            </ng-template>
          }

          <div class="crop-detail__subsection crop-detail__blueprint-add">
            <h3 class="crop-detail__subsection-title">
              {{ 'crops.show.manual_blueprint_add.title' | translate }}
            </h3>
            <p class="crop-detail__subsection-description">
              {{ 'crops.show.manual_blueprint_add.description' | translate }}
            </p>
            @if (control.agriculturalTasksLoading) {
              <p class="master-loading">{{ 'common.loading' | translate }}</p>
            } @else if (!control.unassociatedAgriculturalTasks.length) {
              <div class="crop-detail__template-add-empty">
                <p class="crop-detail__template-add-empty-message">
                  {{
                    (control.blueprints.length
                      ? 'crops.show.manual_blueprint_add.no_unassociated_tasks_all_used'
                      : 'crops.show.manual_blueprint_add.no_unassociated_tasks')
                      | translate
                  }}
                </p>
                <a routerLink="/agricultural_tasks/new" class="btn-secondary crop-detail__template-add-cta">
                  {{ 'crops.show.manual_blueprint_add.go_to_create' | translate }}
                </a>
              </div>
            } @else {
              <div class="crop-detail__template-add-form crop-detail__blueprint-add-form">
                <label class="crop-detail__template-add-field" for="blueprint-task-picker">
                  <span class="crop-detail__template-add-label">
                    {{ 'crops.show.manual_blueprint_add.task_label' | translate }}
                  </span>
                  <select
                    id="blueprint-task-picker"
                    name="blueprintAgriculturalTaskId"
                    class="crop-detail__template-add-select"
                    [class.crop-detail__select--placeholder]="control.selectedBlueprintAgriculturalTaskId == null"
                    [ngModel]="control.selectedBlueprintAgriculturalTaskId"
                    (ngModelChange)="onBlueprintTaskChange($event)"
                  >
                    <option [ngValue]="null">
                      {{ 'crops.show.manual_blueprint_add.task_placeholder' | translate }}
                    </option>
                    @for (task of control.unassociatedAgriculturalTasks; track task.id) {
                      <option [ngValue]="task.id">{{ task.name }}</option>
                    }
                  </select>
                </label>
                @if (control.crop?.crop_stages?.length) {
                  <label class="crop-detail__template-add-field" for="blueprint-stage-picker">
                    <span class="crop-detail__template-add-label">
                      {{ 'crops.show.manual_blueprint_add.stage_label' | translate }}
                      <span class="crop-detail__optional-label">{{ 'crops.show.manual_blueprint_add.optional' | translate }}</span>
                    </span>
                    <select
                      id="blueprint-stage-picker"
                      name="blueprintStageOrder"
                      class="crop-detail__template-add-select"
                      [class.crop-detail__select--placeholder]="control.selectedBlueprintStageOrder == null"
                      [ngModel]="control.selectedBlueprintStageOrder"
                      (ngModelChange)="onBlueprintStageChange($event)"
                    >
                      <option [ngValue]="null">
                        {{ 'crops.show.manual_blueprint_add.stage_placeholder' | translate }}
                      </option>
                      @for (stage of control.crop?.crop_stages ?? []; track stage.id) {
                        <option [ngValue]="stage.order">{{ stage.name }}</option>
                      }
                    </select>
                  </label>
                }
                <label class="crop-detail__template-add-field" for="blueprint-gdd-input">
                  <span class="crop-detail__template-add-label">
                    {{ 'crops.show.manual_blueprint_add.gdd_label' | translate }}
                    <span class="crop-detail__optional-label">{{ 'crops.show.manual_blueprint_add.optional' | translate }}</span>
                  </span>
                  <span class="crop-detail__template-add-input-wrap">
                    <input
                      id="blueprint-gdd-input"
                      type="number"
                      step="0.01"
                      min="0"
                      name="blueprintCreateGddTrigger"
                      class="crop-detail__template-add-input"
                      [ngModel]="control.blueprintCreateGddTrigger"
                      (ngModelChange)="onBlueprintGddCreateChange($event)"
                    />
                    <span class="crop-detail__template-add-input-unit" aria-hidden="true">
                      {{ 'crops.show.gdd_unit' | translate }}
                    </span>
                  </span>
                </label>
                <div class="crop-detail__template-add-actions">
                  <button
                    type="button"
                    class="btn-primary"
                    [disabled]="!control.canCreateBlueprint"
                    (click)="createBlueprint()"
                  >
                    {{
                      (control.blueprintCreating
                        ? 'common.loading'
                        : 'crops.show.manual_blueprint_add.submit')
                        | translate
                    }}
                  </button>
                </div>
              </div>
            }
            <div class="crop-detail__blueprint-ai-import">
              <p class="crop-detail__subsection-description">
                {{ 'crops.show.manual_blueprint_add.ai_hint' | translate }}
              </p>
              <button
                type="button"
                class="btn-secondary"
                [disabled]="!control.canRegenerateBlueprints"
                (click)="regenerateBlueprints()"
              >
                {{
                  (control.blueprintsRegenerating
                    ? 'common.loading'
                    : 'crops.show.generate_task_schedule_blueprints_button')
                    | translate
                }}
              </button>
            </div>
          </div>
        </section>
      }
    </main>
  `,
  styleUrls: ['./crop-detail.component.css']
})
export class CropDetailComponent implements CropDetailView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly useCase = inject(LoadCropDetailUseCase);
  private readonly deleteUseCase = inject(DeleteCropUseCase);
  private readonly loadAgriculturalTasksUseCase = inject(LoadAgriculturalTaskListUseCase);
  private readonly loadBlueprintsUseCase = inject(LoadCropTaskScheduleBlueprintsUseCase);
  private readonly createBlueprintUseCase = inject(CreateCropTaskScheduleBlueprintUseCase);
  private readonly regenerateBlueprintsUseCase = inject(RegenerateCropTaskScheduleBlueprintsUseCase);
  private readonly updateBlueprintUseCase = inject(UpdateCropTaskScheduleBlueprintUseCase);
  private readonly deleteBlueprintUseCase = inject(DeleteCropTaskScheduleBlueprintUseCase);
  private readonly presenter = inject(CropDetailPresenter);
  private readonly undoToast = inject(UndoToastService);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly translate = inject(TranslateService);

  private _control: CropDetailViewState = initialControl;
  get control(): CropDetailViewState {
    return this._control;
  }
  set control(value: CropDetailViewState) {
    const withFromPlan =
      value.fromPlanId !== undefined
        ? value
        : { ...value, fromPlanId: this._control.fromPlanId };
    const next = applyPendingUndoToastViewEffects(
      applyPendingFlashViewEffects(withFromPlan, {
        flash: this.flashMessage
      }),
      { toast: this.undoToast }
    );
    this._control = next;
    this.cdr.markForCheck();
    this.scrollToFragmentIfReady();
  }

  private scrollToFragmentIfReady(): void {
    const fragment = this.route.snapshot.fragment;
    if (!fragment || this.control.loading) {
      return;
    }
    if (fragment === 'blueprints-heading' && this.control.blueprintsLoading) {
      return;
    }
    queueMicrotask(() => {
      document.getElementById(fragment)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  }

  displayDateTime(value: string): string {
    return formatIsoDateTimeForDisplay(value, this.translate.currentLang);
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const fromPlanId = parseFromPlanId(this.route.snapshot.queryParamMap.get('fromPlan'));
    const cropId = Number(this.route.snapshot.paramMap.get('id'));
    if (!cropId) {
      this.control = {
        ...initialControl,
        fromPlanId,
        loading: false,
        agriculturalTasksLoading: false,
        blueprintsLoading: false,
        error: this.translate.instant('crops.errors.invalid_id')
      };
      return;
    }
    this.control = { ...this.control, fromPlanId };
    this.load(cropId);
    this.loadTaskSections(cropId);
  }

  load(cropId: number): void {
    this.control = { ...this.control, loading: true };
    this.useCase.execute({ cropId });
  }

  loadTaskSections(cropId: number): void {
    this.control = {
      ...this.control,
      agriculturalTasksLoading: true,
      blueprintsLoading: true
    };
    this.loadAgriculturalTasksUseCase.execute();
    this.loadBlueprintsUseCase.execute({ cropId });
  }

  reload(): void {
    const cropId = Number(this.route.snapshot.paramMap.get('id'));
    if (cropId) {
      this.load(cropId);
      this.loadTaskSections(cropId);
    }
  }

  onBlueprintStageChange(stageOrder: number | null): void {
    this.control = withCropDetailDisplayState({
      ...this.control,
      selectedBlueprintStageOrder: stageOrder
    });
  }

  onBlueprintTaskChange(agriculturalTaskId: number | null): void {
    this.control = withCropDetailDisplayState({
      ...this.control,
      selectedBlueprintAgriculturalTaskId: agriculturalTaskId
    });
  }

  onBlueprintGddCreateChange(value: number | null): void {
    this.control = { ...this.control, blueprintCreateGddTrigger: value };
  }

  createBlueprint(): void {
    const cropId = this.control.crop?.id;
    const agriculturalTaskId = this.control.selectedBlueprintAgriculturalTaskId;
    if (!cropId || agriculturalTaskId == null) {
      return;
    }
    const stageOrder = this.control.selectedBlueprintStageOrder;
    const gddTrigger = this.control.blueprintCreateGddTrigger;
    this.control = withCropDetailDisplayState({
      ...this.control,
      blueprintCreating: true
    });
    this.createBlueprintUseCase.execute({
      cropId,
      agriculturalTaskId,
      stageOrder: stageOrder ?? null,
      stageName: this.control.blueprintStageNameForCreate,
      gddTrigger:
        gddTrigger != null && !Number.isNaN(gddTrigger) ? gddTrigger : null
    });
  }

  regenerateBlueprints(): void {
    const cropId = this.control.crop?.id;
    if (!cropId) return;
    if (!confirm(this.translate.instant('crops.show.generate_task_schedule_blueprints_confirm'))) return;
    this.regenerateBlueprintsUseCase.execute({ cropId });
  }

  onBlueprintDropped(
    event: CdkDragDrop<CropTaskScheduleBlueprint[]>,
    targetStageOrder: number | null
  ): void {
    const cropId = this.control.crop?.id;
    if (!cropId) return;
    const blueprint = event.item.data as CropTaskScheduleBlueprint;
    const cropStages = this.control.crop?.crop_stages?.map((stage) => ({
      order: stage.order,
      name: stage.name
    }));
    this.updateBlueprintUseCase.executeDrop({
      cropId,
      dragged: blueprint,
      targetStageOrder,
      laneBlueprints: event.container.data,
      dropIndex: event.currentIndex,
      cropStages
    });
  }

  blueprintLaneId(lane: BlueprintStageLane): string {
    return lane.stageOrder == null ? 'blueprint-lane-unassigned' : `blueprint-lane-${lane.stageOrder}`;
  }

  onGddDraftChange(blueprintId: number, value: number): void {
    this.control = {
      ...this.control,
      blueprintGddDrafts: {
        ...this.control.blueprintGddDrafts,
        [blueprintId]: value
      }
    };
  }

  saveBlueprintGdd(blueprintId: number): void {
    const cropId = this.control.crop?.id;
    const gddTrigger = this.control.blueprintGddDrafts[blueprintId];
    if (!cropId || gddTrigger == null || Number.isNaN(gddTrigger)) return;
    this.updateBlueprintUseCase.execute({ cropId, blueprintId, gddTrigger });
  }

  deleteBlueprint(blueprintId: number): void {
    const cropId = this.control.crop?.id;
    if (!cropId) return;
    if (!confirm(this.translate.instant('crops.show.delete_blueprint_confirm'))) return;
    this.deleteBlueprintUseCase.execute({ cropId, blueprintId });
  }

  deleteCrop(): void {
    if (!this.control.crop) return;
    this.deleteUseCase.execute({
      cropId: this.control.crop.id,
      onSuccess: () => this.router.navigate(['/crops'])
    });
  }
}
