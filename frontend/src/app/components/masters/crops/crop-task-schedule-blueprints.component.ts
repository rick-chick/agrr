import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { CdkDragDrop, DragDropModule } from '@angular/cdk/drag-drop';
import {
  CropTaskScheduleBlueprintsView,
  CropTaskScheduleBlueprintsViewState
} from './crop-task-schedule-blueprints.view';
import { LoadCropDetailUseCase } from '../../../usecase/crops/load-crop-detail.usecase';
import { LoadAgriculturalTaskListUseCase } from '../../../usecase/agricultural-tasks/load-agricultural-task-list.usecase';
import { LoadCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/load-crop-task-schedule-blueprints.usecase';
import { CreateCropTaskScheduleBlueprintUseCase } from '../../../usecase/crops/create-crop-task-schedule-blueprint.usecase';
import { RegenerateCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/regenerate-crop-task-schedule-blueprints.usecase';
import { UpdateCropTaskScheduleBlueprintUseCase } from '../../../usecase/crops/update-crop-task-schedule-blueprint.usecase';
import { DeleteCropTaskScheduleBlueprintUseCase } from '../../../usecase/crops/delete-crop-task-schedule-blueprint.usecase';
import {
  CropTaskScheduleBlueprintsPresenter,
  CROP_TASK_SCHEDULE_BLUEPRINTS_PROVIDERS
} from '../../../usecase/crops/crop-task-schedule-blueprints.providers';
import { FlashMessageService } from '../../../services/flash-message.service';
import { applyPendingFlashViewEffects } from '../../../core/view-effects/pending-success-flash-view.effects';
import { BlueprintStageLane } from '../../../domain/crops/blueprint-stage-grouping';
import type { CumulativeGddTimelineSegment } from '../../../domain/crops/cumulative-gdd-timeline';
import { CropTaskScheduleBlueprint } from '../../../domain/crops/crop-task-schedule-blueprint';
import type { BlueprintGddValidationError } from '../../../domain/crops/blueprint-gdd-validation';
import { stageCumulativeGddRange } from '../../../domain/crops/stage-cumulative-gdd';
import { defaultBlueprintReadiness } from '../../../domain/crops/blueprint-generation-readiness';
import { parseFromPlanId } from '../../../domain/crops/parse-from-plan-id';
import {
  cropPlanWizardQueryParams,
  parsePlanWizardReturnTab,
  planWizardReturnPath,
  type PlanWizardReturnTab
} from '../../../domain/crops/plan-wizard-context';

const initialControl: CropTaskScheduleBlueprintsViewState = {
  loading: true,
  error: null,
  crop: null,
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
  blueprintGddTouched: {},
  blueprintStageLanes: [],
  cumulativeGddTimelineSegments: [],
  blueprintGddErrors: {},
  blueprintLaneOutOfRangeCounts: {},
  blueprintCreateGddError: null,
  blueprintCreateFormAttempted: false,
  selectedStageGddRange: null,
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
  selector: 'app-crop-task-schedule-blueprints',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, TranslateModule, DragDropModule],
  providers: [...CROP_TASK_SCHEDULE_BLUEPRINTS_PROVIDERS],
  template: `
    <main class="page-main">
      @if (control.loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (control.error) {
        <p class="master-loading master-error">{{ control.error }}</p>
      } @else if (control.crop) {
        @if (control.fromPlanId) {
          <div class="crop-blueprints__plan-wizard-banner" role="status">
            <p class="crop-blueprints__plan-wizard-banner-title">
              {{ 'crops.show.from_plan_wizard_title' | translate }}
            </p>
            <p class="crop-blueprints__plan-wizard-banner-lead">
              {{ 'crops.show.from_plan_wizard_lead' | translate }}
            </p>
          </div>
        }

        <header class="page-header crop-blueprints__page-header">
          <nav class="crop-blueprints__nav" aria-label="{{ 'crops.show.task_schedule_blueprints_title' | translate }}">
            <a [routerLink]="['/crops', control.crop.id]" class="crop-blueprints__back-link">
              {{ 'common.back' | translate }}
            </a>
            @if (control.fromPlanId) {
              <a [routerLink]="planReturnPath" class="btn-secondary">
                {{ 'crops.show.return_to_plan' | translate }}
              </a>
            }
          </nav>
          <h1 class="page-title">{{ control.crop.name }}</h1>
          <p class="page-description">{{ 'crops.show.task_schedule_blueprints_title' | translate }}</p>
        </header>

        <section class="section-card" aria-labelledby="blueprints-heading">
          <div class="section-card__header-actions crop-blueprints__blueprints-header">
            <h2 id="blueprints-heading" class="section-title">
              {{ 'crops.show.task_schedule_blueprints_title' | translate }}
            </h2>
          </div>
          <p
            class="section-card__description"
            [innerHTML]="control.blueprintSectionDescriptionKey | translate"
          ></p>
          @if (control.crop?.crop_stages?.length) {
            <p class="crop-blueprints__gdd-intro">
              {{ 'crops.show.task_schedule_blueprints_gdd_intro' | translate }}
            </p>
          }

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
                    <a
                      [routerLink]="['/crops', control.crop.id, 'stages']"
                      [queryParams]="wizardQueryParams"
                      class="blueprint-readiness__link"
                    >
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
                  <a
                    [routerLink]="['/crops', control.crop.id, 'stages']"
                    [queryParams]="wizardQueryParams"
                    class="blueprint-readiness__link"
                  >
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
              @if (control.cumulativeGddTimelineSegments.length) {
                <div
                  class="blueprint-gdd-axis"
                  role="img"
                  [attr.aria-label]="
                    'crops.show.task_schedule_blueprints_gdd_axis_label'
                      | translate: { total: gddAxisTotalGdd(control.cumulativeGddTimelineSegments) }
                  "
                >
                  <p class="blueprint-gdd-axis__hint">
                    {{ 'crops.show.task_schedule_blueprints_gdd_axis_hint' | translate }}
                  </p>
                  <div class="blueprint-gdd-axis__bar">
                    @for (segment of control.cumulativeGddTimelineSegments; track segment.stageOrder) {
                      <div
                        class="blueprint-gdd-axis__segment"
                        [style.flex-grow]="segment.cumulativeGddEnd - segment.cumulativeGddStart"
                      >
                        <span class="blueprint-gdd-axis__segment-label">
                          <span class="blueprint-gdd-axis__segment-name">{{ segment.stageName }}</span>
                          <span class="blueprint-gdd-axis__segment-gdd">
                            {{
                              'crops.show.blueprint_stage_lane.gdd_range'
                                | translate: {
                                    start: segment.cumulativeGddStart,
                                    end: segment.cumulativeGddEnd
                                  }
                            }}
                          </span>
                        </span>
                      </div>
                    }
                  </div>
                </div>
              }
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
                        <span class="blueprint-stage-lane__name">
                          {{ 'crops.show.blueprint_stage_lane.unassigned' | translate }}
                        </span>
                        <span class="blueprint-stage-lane__gdd-range blueprint-stage-lane__gdd-range--warn">
                          {{ 'crops.show.blueprint_stage_lane.unassigned_hint' | translate }}
                        </span>
                      } @else {
                        <span class="blueprint-stage-lane__name">{{ lane.stageName }}</span>
                        @if (lane.gddRangeMissing) {
                          <span class="blueprint-stage-lane__gdd-range blueprint-stage-lane__gdd-range--warn">
                            {{ 'crops.show.blueprint_stage_lane.gdd_range_missing' | translate }}
                          </span>
                        } @else {
                          <span class="blueprint-stage-lane__gdd-range">
                            {{
                              'crops.show.blueprint_stage_lane.gdd_range'
                                | translate: {
                                    start: lane.cumulativeGddStart,
                                    end: lane.cumulativeGddEnd
                                  }
                            }}
                          </span>
                        }
                        @if (
                          lane.stageOrder != null &&
                          control.blueprintLaneOutOfRangeCounts[lane.stageOrder];
                          as outOfRangeCount
                        ) {
                          <span class="blueprint-stage-lane__lane-warning" role="status">
                            {{
                              'crops.show.blueprint_stage_lane.out_of_range_count'
                                | translate: {
                                    count: outOfRangeCount,
                                    start: lane.cumulativeGddStart,
                                    end: lane.cumulativeGddEnd
                                  }
                            }}
                          </span>
                        }
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
                  class="crop-blueprints__card-remove blueprint-card__remove"
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
                  @if (blueprint.gdd_trigger == null && control.blueprintGddDrafts[blueprint.id] == null) {
                    <span class="blueprint-card__unset-badge" role="status">
                      {{ 'crops.show.blueprint_gdd_unset' | translate }}
                    </span>
                  }
                  <span class="crop-blueprints__template-add-input-wrap">
                    <input
                      [id]="'gdd-' + blueprint.id"
                      type="number"
                      step="0.01"
                      min="0"
                      class="crop-blueprints__template-add-input blueprint-card__input"
                      [class.blueprint-card__input--invalid]="
                        control.blueprintGddTouched[blueprint.id] &&
                        control.blueprintGddErrors[blueprint.id]
                      "
                      [ngModel]="control.blueprintGddDrafts[blueprint.id]"
                      (ngModelChange)="onGddDraftChange(blueprint.id, $event)"
                      (change)="saveBlueprintGdd(blueprint.id)"
                      [disabled]="control.blueprintSavingId === blueprint.id"
                      [attr.placeholder]="gddPlaceholderForBlueprint(blueprint)"
                      [attr.aria-invalid]="
                        control.blueprintGddTouched[blueprint.id] &&
                        control.blueprintGddErrors[blueprint.id]
                          ? true
                          : null
                      "
                      [attr.aria-describedby]="
                        control.blueprintGddTouched[blueprint.id] &&
                        control.blueprintGddErrors[blueprint.id]
                          ? 'gdd-error-' + blueprint.id
                          : null
                      "
                    />
                    <span class="crop-blueprints__template-add-input-unit" aria-hidden="true">
                      {{ 'crops.show.gdd_unit' | translate }}
                    </span>
                  </span>
                  @if (
                    control.blueprintGddTouched[blueprint.id] &&
                    control.blueprintGddErrors[blueprint.id];
                    as gddError
                  ) {
                    <span
                      class="blueprint-card__field-error"
                      [id]="'gdd-error-' + blueprint.id"
                      role="alert"
                    >
                      {{ gddValidationMessage(gddError, blueprint.stage_order, blueprint.stage_name) }}
                    </span>
                  }
                </label>
              </div>
            </ng-template>
          }

          <div class="crop-blueprints__subsection crop-blueprints__blueprint-add">
            <h3 class="crop-blueprints__subsection-title">
              {{ 'crops.show.manual_blueprint_add.title' | translate }}
            </h3>
            <p class="crop-blueprints__subsection-description">
              {{ 'crops.show.manual_blueprint_add.description' | translate }}
            </p>
            @if (control.agriculturalTasksLoading) {
              <p class="master-loading">{{ 'common.loading' | translate }}</p>
            } @else if (!control.unassociatedAgriculturalTasks.length) {
              <div class="crop-blueprints__template-add-empty">
                <p class="crop-blueprints__template-add-empty-message">
                  {{
                    (control.blueprints.length
                      ? 'crops.show.manual_blueprint_add.no_unassociated_tasks_all_used'
                      : 'crops.show.manual_blueprint_add.no_unassociated_tasks')
                      | translate
                  }}
                </p>
                <a routerLink="/agricultural_tasks/new" class="btn-secondary crop-blueprints__template-add-cta">
                  {{ 'crops.show.manual_blueprint_add.go_to_create' | translate }}
                </a>
              </div>
            } @else {
              <div class="crop-blueprints__template-add-form crop-blueprints__blueprint-add-form">
                <label class="crop-blueprints__template-add-field" for="blueprint-task-picker">
                  <span class="crop-blueprints__template-add-label">
                    {{ 'crops.show.manual_blueprint_add.task_label' | translate }}
                  </span>
                  <select
                    id="blueprint-task-picker"
                    name="blueprintAgriculturalTaskId"
                    class="crop-blueprints__template-add-select"
                    [class.crop-blueprints__select--placeholder]="control.selectedBlueprintAgriculturalTaskId == null"
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
                  <label class="crop-blueprints__template-add-field" for="blueprint-stage-picker">
                    <span class="crop-blueprints__template-add-label">
                      {{ 'crops.show.manual_blueprint_add.stage_label' | translate }}
                    </span>
                    <select
                      id="blueprint-stage-picker"
                      name="blueprintStageOrder"
                      class="crop-blueprints__template-add-select"
                      [class.crop-blueprints__select--placeholder]="control.selectedBlueprintStageOrder == null"
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
                <label class="crop-blueprints__template-add-field" for="blueprint-gdd-input">
                  <span class="crop-blueprints__template-add-label">
                    {{ 'crops.show.manual_blueprint_add.gdd_label' | translate }}
                  </span>
                  @if (control.selectedStageGddRange && !control.selectedStageGddRange.gddRangeMissing) {
                    <span class="crop-blueprints__template-add-hint">
                      {{
                        'crops.show.manual_blueprint_add.gdd_range_hint'
                          | translate: {
                              start: control.selectedStageGddRange.cumulativeGddStart,
                              end: control.selectedStageGddRange.cumulativeGddEnd
                            }
                      }}
                    </span>
                  }
                  <span class="crop-blueprints__template-add-input-wrap">
                    <input
                      id="blueprint-gdd-input"
                      type="number"
                      step="0.01"
                      min="0"
                      name="blueprintCreateGddTrigger"
                      class="crop-blueprints__template-add-input"
                      [class.blueprint-card__input--invalid]="
                        control.blueprintCreateFormAttempted && control.blueprintCreateGddError
                      "
                      [ngModel]="control.blueprintCreateGddTrigger"
                      (ngModelChange)="onBlueprintGddCreateChange($event)"
                      [attr.placeholder]="createGddPlaceholder()"
                      [attr.aria-invalid]="
                        control.blueprintCreateFormAttempted && control.blueprintCreateGddError
                          ? true
                          : null
                      "
                    />
                    <span class="crop-blueprints__template-add-input-unit" aria-hidden="true">
                      {{ 'crops.show.gdd_unit' | translate }}
                    </span>
                  </span>
                  @if (control.blueprintCreateFormAttempted && control.blueprintCreateGddError; as createGddError) {
                    <span class="blueprint-card__field-error" role="alert">
                      {{
                        gddValidationMessage(
                          createGddError,
                          control.selectedBlueprintStageOrder,
                          control.blueprintStageNameForCreate
                        )
                      }}
                    </span>
                  }
                </label>
                <div class="crop-blueprints__template-add-actions">
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
            <div class="crop-blueprints__blueprint-ai-import">
              <p class="crop-blueprints__subsection-description">
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
  styleUrls: ['./crop-task-schedule-blueprints.component.css']
})
export class CropTaskScheduleBlueprintsComponent implements CropTaskScheduleBlueprintsView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly useCase = inject(LoadCropDetailUseCase);
  private readonly loadAgriculturalTasksUseCase = inject(LoadAgriculturalTaskListUseCase);
  private readonly loadBlueprintsUseCase = inject(LoadCropTaskScheduleBlueprintsUseCase);
  private readonly createBlueprintUseCase = inject(CreateCropTaskScheduleBlueprintUseCase);
  private readonly regenerateBlueprintsUseCase = inject(RegenerateCropTaskScheduleBlueprintsUseCase);
  private readonly updateBlueprintUseCase = inject(UpdateCropTaskScheduleBlueprintUseCase);
  private readonly deleteBlueprintUseCase = inject(DeleteCropTaskScheduleBlueprintUseCase);
  private readonly presenter = inject(CropTaskScheduleBlueprintsPresenter);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly translate = inject(TranslateService);

  returnTab: PlanWizardReturnTab = 'task_schedule';

  get planReturnPath(): (string | number)[] {
    const planId = this.control.fromPlanId;
    return planId != null ? planWizardReturnPath(planId, this.returnTab) : [];
  }

  get wizardQueryParams(): ReturnType<typeof cropPlanWizardQueryParams> | null {
    const planId = this.control.fromPlanId;
    return planId != null ? cropPlanWizardQueryParams(planId, this.returnTab) : null;
  }

  private _control: CropTaskScheduleBlueprintsViewState = initialControl;
  get control(): CropTaskScheduleBlueprintsViewState {
    return this._control;
  }
  set control(value: CropTaskScheduleBlueprintsViewState) {
    const withFromPlan =
      value.fromPlanId !== undefined
        ? value
        : { ...value, fromPlanId: this._control.fromPlanId };
    const next = applyPendingFlashViewEffects(withFromPlan, {
      flash: this.flashMessage
    });
    this._control = this.applyFromPlanDescriptionKey(next);
    this.cdr.markForCheck();
  }

  private applyFromPlanDescriptionKey(
    state: CropTaskScheduleBlueprintsViewState
  ): CropTaskScheduleBlueprintsViewState {
    if (state.fromPlanId == null) {
      return state;
    }
    return {
      ...state,
      blueprintSectionDescriptionKey: 'crops.show.task_schedule_blueprints_description_from_plan_html'
    };
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const fromPlanId = parseFromPlanId(this.route.snapshot.queryParamMap.get('fromPlan'));
    this.returnTab = parsePlanWizardReturnTab(this.route.snapshot.queryParamMap.get('returnTo'));
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
    this.presenter.applyLocalControl({ selectedBlueprintStageOrder: stageOrder });
  }

  onBlueprintTaskChange(agriculturalTaskId: number | null): void {
    this.presenter.applyLocalControl({ selectedBlueprintAgriculturalTaskId: agriculturalTaskId });
  }

  onBlueprintGddCreateChange(value: number | null): void {
    this.presenter.applyLocalControl({ blueprintCreateGddTrigger: value });
  }

  gddValidationMessage(
    error: BlueprintGddValidationError,
    stageOrder: number | null,
    stageName: string | null
  ): string {
    const stages = this.control.crop?.crop_stages ?? [];
    const range =
      stageOrder == null ? null : stageCumulativeGddRange(stages, stageOrder);
    const resolvedStageName = stageName ?? '';
    switch (error) {
      case 'missing_stage':
        return this.translate.instant('crops.show.blueprint_gdd_errors.missing_stage');
      case 'stage_gdd_missing':
        return this.translate.instant('crops.show.blueprint_gdd_errors.stage_gdd_missing');
      case 'out_of_range':
        return this.translate.instant('crops.show.blueprint_gdd_errors.out_of_range', {
          stageName: resolvedStageName,
          start: range?.cumulativeGddStart ?? 0,
          end: range?.cumulativeGddEnd ?? 0
        });
    }
  }

  gddPlaceholderForBlueprint(blueprint: CropTaskScheduleBlueprint): string | null {
    if (blueprint.gdd_trigger != null) {
      return null;
    }
    const stages = this.control.crop?.crop_stages ?? [];
    if (blueprint.stage_order == null || stages.length === 0) {
      return this.translate.instant('crops.show.gdd_trigger_placeholder');
    }
    const range = stageCumulativeGddRange(stages, blueprint.stage_order);
    if (range.gddRangeMissing || range.cumulativeGddStart == null) {
      return this.translate.instant('crops.show.gdd_trigger_placeholder');
    }
    return String(range.cumulativeGddStart);
  }

  createGddPlaceholder(): string | null {
    const range = this.control.selectedStageGddRange;
    if (!range || range.gddRangeMissing || range.cumulativeGddStart == null) {
      return this.translate.instant('crops.show.gdd_trigger_placeholder');
    }
    return String(range.cumulativeGddStart);
  }

  createBlueprint(): void {
    const cropId = this.control.crop?.id;
    const agriculturalTaskId = this.control.selectedBlueprintAgriculturalTaskId;
    if (!cropId || agriculturalTaskId == null) {
      return;
    }

    this.presenter.applyLocalControl({ blueprintCreateFormAttempted: true });

    if (!this.control.canCreateBlueprint) {
      return;
    }

    const stageOrder = this.control.selectedBlueprintStageOrder;
    const gddTrigger = this.control.blueprintCreateGddTrigger;

    this.presenter.applyLocalControl({ blueprintCreating: true });
    this.createBlueprintUseCase.execute({
      cropId,
      agriculturalTaskId,
      stageOrder: stageOrder ?? null,
      stageName: this.control.blueprintStageNameForCreate,
      gddTrigger: gddTrigger != null && !Number.isNaN(gddTrigger) ? gddTrigger : null
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

  gddAxisTotalGdd(segments: CumulativeGddTimelineSegment[]): number {
    if (!segments.length) {
      return 0;
    }
    return segments[segments.length - 1].cumulativeGddEnd;
  }

  blueprintLaneId(lane: BlueprintStageLane): string {
    return lane.stageOrder == null ? 'blueprint-lane-unassigned' : `blueprint-lane-${lane.stageOrder}`;
  }

  onGddDraftChange(blueprintId: number, value: number): void {
    this.presenter.applyLocalControl({
      blueprintGddTouched: {
        ...this.control.blueprintGddTouched,
        [blueprintId]: true
      },
      blueprintGddDrafts: {
        ...this.control.blueprintGddDrafts,
        [blueprintId]: value
      }
    });
  }

  saveBlueprintGdd(blueprintId: number): void {
    const cropId = this.control.crop?.id;
    const gddTrigger = this.control.blueprintGddDrafts[blueprintId];
    if (!cropId || gddTrigger == null || Number.isNaN(gddTrigger)) return;

    this.presenter.applyLocalControl({
      blueprintGddTouched: {
        ...this.control.blueprintGddTouched,
        [blueprintId]: true
      }
    });

    if (this.control.blueprintGddErrors[blueprintId]) {
      return;
    }

    this.updateBlueprintUseCase.execute({ cropId, blueprintId, gddTrigger });
  }

  deleteBlueprint(blueprintId: number): void {
    const cropId = this.control.crop?.id;
    if (!cropId) return;
    if (!confirm(this.translate.instant('crops.show.delete_blueprint_confirm'))) return;
    this.deleteBlueprintUseCase.execute({ cropId, blueprintId });
  }
}
