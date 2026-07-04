import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { CropDetailView, CropDetailViewState } from './crop-detail.view';
import { LoadCropDetailUseCase } from '../../../usecase/crops/load-crop-detail.usecase';
import { DeleteCropUseCase } from '../../../usecase/crops/delete-crop.usecase';
import { LoadCropTaskTemplatesUseCase } from '../../../usecase/crops/load-crop-task-templates.usecase';
import { CreateCropTaskTemplateUseCase } from '../../../usecase/crops/create-crop-task-template.usecase';
import { DeleteCropTaskTemplateUseCase } from '../../../usecase/crops/delete-crop-task-template.usecase';
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
import { blueprintGenerationReadiness } from '../../../domain/crops/blueprint-generation-readiness';
import { blueprintRegenerateErrorShowsRetry } from '../../../core/crop-blueprint-regenerate-error-i18n';

const initialControl: CropDetailViewState = {
  loading: true,
  error: null,
  crop: null,
  pendingUndoToast: null,
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  taskTemplatesLoading: true,
  taskTemplates: [],
  agriculturalTasksLoading: true,
  agriculturalTasks: [],
  unassociatedAgriculturalTasks: [],
  selectedAgriculturalTaskId: null,
  taskTemplateCreating: false,
  blueprintsLoading: true,
  blueprints: [],
  blueprintsRegenerating: false,
  blueprintGddSavingId: null,
  blueprintGddDrafts: {},
  blueprintRegenerateError: null,
  selectedBlueprintStageOrder: null,
  selectedBlueprintAgriculturalTaskId: null,
  blueprintCreateGddTrigger: null,
  blueprintCreating: false
};

@Component({
  selector: 'app-crop-detail',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, TranslateModule],
  providers: [...CROP_DETAIL_PROVIDERS],
  template: `
    <main class="page-main">
      @if (control.loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (control.crop) {
        @if (fromPlanId) {
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
            @if (fromPlanId) {
              <a [routerLink]="['/plans', fromPlanId, 'work']" class="btn-secondary">{{ 'crops.show.return_to_plan' | translate }}</a>
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

        <section class="section-card" aria-labelledby="task-templates-heading">
          <h2 id="task-templates-heading" class="section-title">
            <span class="crop-detail__step-badge">{{ 'crops.show.agricultural_tasks_step_label' | translate }}</span>
            {{ 'crops.show.agricultural_tasks_title' | translate }}
          </h2>
          <p class="section-card__description">{{ 'crops.show.agricultural_tasks_description' | translate }}</p>
          @if (control.taskTemplatesLoading) {
            <p class="master-loading">{{ 'common.loading' | translate }}</p>
          } @else if (!control.taskTemplates.length) {
            <p class="section-card__description">{{ 'crops.show.no_agricultural_tasks_description' | translate }}</p>
          } @else {
            <ul class="card-list" role="list">
              @for (template of control.taskTemplates; track template.id) {
                <li class="card-list__item">
                  <article class="item-card">
                    <div class="item-card__body">
                      <span class="item-card__title">{{ template.name }}</span>
                      @if (template.agricultural_task?.is_reference) {
                        <span class="item-card__meta">{{ 'crops.show.reference_task' | translate }}</span>
                      }
                      @if (template.description) {
                        <span class="item-card__meta">{{ template.description }}</span>
                      }
                    </div>
                    <div class="item-card__actions">
                      <button
                        type="button"
                        class="crop-detail__card-remove"
                        (click)="deleteTaskTemplate(template.id)"
                        [attr.aria-label]="'common.delete' | translate"
                      >
                        {{ 'common.delete' | translate }}
                      </button>
                    </div>
                  </article>
                </li>
              }
            </ul>
          }

          <div class="crop-detail__subsection crop-detail__template-add">
            <h3 class="crop-detail__subsection-title">
              {{ 'crops.agricultural_tasks.new.associate_existing_task' | translate }}
            </h3>
            <p class="crop-detail__subsection-description">
              {{ 'crops.agricultural_tasks.new.associate_existing_task_description' | translate }}
            </p>
            @if (control.agriculturalTasksLoading) {
              <p class="master-loading">{{ 'common.loading' | translate }}</p>
            } @else if (!control.unassociatedAgriculturalTasks.length) {
              <div class="crop-detail__template-add-empty">
                <p class="crop-detail__template-add-empty-message">
                  {{
                    (control.taskTemplates.length
                      ? 'crops.agricultural_tasks.new.no_unassociated_tasks_all_templated'
                      : 'crops.agricultural_tasks.new.no_unassociated_tasks')
                      | translate
                  }}
                </p>
                <a routerLink="/agricultural_tasks/new" class="btn-secondary crop-detail__template-add-cta">
                  {{ 'crops.agricultural_tasks.new.go_to_create' | translate }}
                </a>
              </div>
            } @else {
              <div class="crop-detail__template-add-form">
                <label class="crop-detail__template-add-field" for="agricultural-task-picker">
                  <span class="crop-detail__template-add-label">
                    {{ 'crops.agricultural_tasks.new.select_existing_task' | translate }}
                  </span>
                  <select
                    id="agricultural-task-picker"
                    name="agriculturalTaskId"
                    class="crop-detail__template-add-select"
                    [class.crop-detail__select--placeholder]="control.selectedAgriculturalTaskId == null"
                    [ngModel]="control.selectedAgriculturalTaskId"
                    (ngModelChange)="onSelectedTaskChange($event)"
                  >
                    <option [ngValue]="null">
                      {{ 'crops.agricultural_tasks.new.select_task_placeholder' | translate }}
                    </option>
                    @for (task of control.unassociatedAgriculturalTasks; track task.id) {
                      <option [ngValue]="task.id">{{ task.name }}</option>
                    }
                  </select>
                </label>
                <div class="crop-detail__template-add-actions">
                  <button
                    type="button"
                    class="btn-primary"
                    [disabled]="!control.selectedAgriculturalTaskId || control.taskTemplateCreating"
                    (click)="createTaskTemplate()"
                  >
                    {{
                      (control.taskTemplateCreating
                        ? 'common.loading'
                        : 'crops.agricultural_tasks.new.associate_button')
                        | translate
                    }}
                  </button>
                </div>
              </div>
            }
          </div>
        </section>

        <section class="section-card" aria-labelledby="blueprints-heading">
          <div class="section-card__header-actions crop-detail__blueprints-header">
            <h2 id="blueprints-heading" class="section-title">
              <span class="crop-detail__step-badge">{{ 'crops.show.task_schedule_blueprints_step_label' | translate }}</span>
              {{ 'crops.show.task_schedule_blueprints_title' | translate }}
            </h2>
          </div>
          <p
            class="section-card__description"
            [innerHTML]="blueprintSectionDescriptionKey | translate"
          ></p>

          @if (showBlueprintReadinessChecklist) {
            <div class="blueprint-readiness" role="status">
              <p class="blueprint-readiness__title">{{ 'crops.show.blueprint_readiness.title' | translate }}</p>
              <ul class="blueprint-readiness__list">
                <li [class.blueprint-readiness__item--ok]="blueprintReadiness.templatesReady">
                  @if (blueprintReadiness.templatesReady) {
                    <span>{{ 'crops.show.blueprint_readiness.templates_ready' | translate }}</span>
                  } @else {
                    <span>{{ 'crops.show.blueprint_readiness.templates_missing' | translate }}</span>
                    <a href="#task-templates-heading" class="blueprint-readiness__link">
                      {{ 'crops.show.blueprint_readiness.templates_action' | translate }}
                    </a>
                  }
                </li>
                <li [class.blueprint-readiness__item--ok]="blueprintReadiness.stageRequirementsReady">
                  @if (blueprintReadiness.stageRequirementsReady) {
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
              @if (!blueprintReadiness.templatesReady) {
                <p>
                  <a href="#task-templates-heading" class="blueprint-readiness__link">
                    {{ 'crops.show.blueprint_readiness.templates_action' | translate }}
                  </a>
                </p>
              }
              @if (!blueprintReadiness.stageRequirementsReady) {
                <p>
                  <a [routerLink]="['/crops', control.crop.id, 'edit']" class="blueprint-readiness__link">
                    {{ 'crops.show.blueprint_readiness.stages_action' | translate }}
                  </a>
                </p>
              }
              @if (showBlueprintRegenerateRetry) {
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
          } @else if (showBlueprintEmptyState) {
            <p>{{ 'crops.show.no_task_schedule_blueprints' | translate }}</p>
          } @else {
            <ul class="card-list crop-detail__blueprint-list" role="list">
              @for (blueprint of control.blueprints; track blueprint.id) {
                <li class="card-list__item">
                  <article class="item-card blueprint-card">
                    <div class="item-card__body">
                      <span class="item-card__title">
                        {{ blueprint.stage_name || ('crops.show.stage_name' | translate) }}
                        <span class="item-card__meta">#{{ blueprint.stage_order }}</span>
                      </span>
                      @if (blueprint.agricultural_task) {
                        <span class="item-card__meta">{{ blueprint.agricultural_task.name }}</span>
                      } @else if (blueprint.name) {
                        <span class="item-card__meta">{{ blueprint.name }}</span>
                      }
                      @if (blueprint.description) {
                        <span class="item-card__meta">{{ blueprint.description }}</span>
                      }
                      <label class="blueprint-card__gdd" [attr.for]="'gdd-' + blueprint.id">
                        <span class="blueprint-card__gdd-label">
                          {{ 'crops.show.gdd_trigger' | translate }}
                        </span>
                        <span class="crop-detail__template-add-input-wrap">
                          <input
                            [id]="'gdd-' + blueprint.id"
                            type="number"
                            step="0.01"
                            min="0"
                            class="crop-detail__template-add-input"
                            [ngModel]="control.blueprintGddDrafts[blueprint.id]"
                            (ngModelChange)="onGddDraftChange(blueprint.id, $event)"
                            (change)="saveBlueprintGdd(blueprint.id)"
                            [disabled]="control.blueprintGddSavingId === blueprint.id"
                          />
                          <span class="crop-detail__template-add-input-unit" aria-hidden="true">
                            {{ 'crops.show.gdd_unit' | translate }}
                          </span>
                        </span>
                      </label>
                    </div>
                    <div class="item-card__actions">
                      <button
                        type="button"
                        class="crop-detail__card-remove"
                        (click)="deleteBlueprint(blueprint.id)"
                        [attr.aria-label]="'crops.show.delete_blueprint' | translate"
                      >
                        {{ 'common.delete' | translate }}
                      </button>
                    </div>
                  </article>
                </li>
              }
            </ul>
          }

          <div class="crop-detail__subsection crop-detail__blueprint-add">
            <h3 class="crop-detail__subsection-title">
              {{ 'crops.show.manual_blueprint_add.title' | translate }}
            </h3>
            <p class="crop-detail__subsection-description">
              {{ 'crops.show.manual_blueprint_add.description' | translate }}
            </p>
            @if (!blueprintReadiness.ready) {
              <p class="crop-detail__template-add-empty-message">
                {{ 'crops.show.manual_blueprint_add.prerequisites' | translate }}
              </p>
            } @else {
              <div class="crop-detail__template-add-form crop-detail__blueprint-add-form">
                <label class="crop-detail__template-add-field" for="blueprint-stage-picker">
                  <span class="crop-detail__template-add-label">
                    {{ 'crops.show.manual_blueprint_add.stage_label' | translate }}
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
                    @for (template of control.taskTemplates; track template.id) {
                      <option [ngValue]="template.agricultural_task_id">{{ template.name }}</option>
                    }
                  </select>
                </label>
                <label class="crop-detail__template-add-field" for="blueprint-gdd-input">
                  <span class="crop-detail__template-add-label">
                    {{ 'crops.show.manual_blueprint_add.gdd_label' | translate }}
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
                    [disabled]="!canCreateBlueprint"
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
                [disabled]="!canRegenerateBlueprints"
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
  private readonly loadTaskTemplatesUseCase = inject(LoadCropTaskTemplatesUseCase);
  private readonly createTaskTemplateUseCase = inject(CreateCropTaskTemplateUseCase);
  private readonly deleteTaskTemplateUseCase = inject(DeleteCropTaskTemplateUseCase);
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
    const next = applyPendingUndoToastViewEffects(
      applyPendingFlashViewEffects(value, { flash: this.flashMessage }),
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
    if (fragment === 'task-templates-heading' && this.control.taskTemplatesLoading) {
      return;
    }
    queueMicrotask(() => {
      document.getElementById(fragment)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  }

  displayDateTime(value: string): string {
    return formatIsoDateTimeForDisplay(value, this.translate.currentLang);
  }

  get blueprintReadiness() {
    return blueprintGenerationReadiness(this.control.crop, this.control.taskTemplates);
  }

  get canRegenerateBlueprints(): boolean {
    return this.blueprintReadiness.ready && !this.control.blueprintsRegenerating;
  }

  get canCreateBlueprint(): boolean {
    return (
      this.blueprintReadiness.ready &&
      !this.control.blueprintCreating &&
      this.control.selectedBlueprintStageOrder != null &&
      this.control.selectedBlueprintAgriculturalTaskId != null &&
      this.control.blueprintCreateGddTrigger != null &&
      !Number.isNaN(this.control.blueprintCreateGddTrigger) &&
      this.control.blueprintCreateGddTrigger >= 0
    );
  }

  get blueprintStageNameForCreate(): string | null {
    const order = this.control.selectedBlueprintStageOrder;
    if (order == null) return null;
    return (
      this.control.crop?.crop_stages?.find((stage) => stage.order === order)?.name ?? null
    );
  }

  get showBlueprintReadinessChecklist(): boolean {
    return (
      !this.control.taskTemplatesLoading &&
      !this.blueprintReadiness.ready &&
      !this.control.blueprintsRegenerating
    );
  }

  get blueprintSectionDescriptionKey(): string {
    return this.control.blueprints.length
      ? 'crops.show.task_schedule_blueprints_description_html'
      : 'crops.show.task_schedule_blueprints_description_empty_html';
  }

  get showBlueprintEmptyState(): boolean {
    return !this.control.blueprints.length && !this.control.blueprintRegenerateError;
  }

  get showBlueprintRegenerateRetry(): boolean {
    return (
      this.blueprintReadiness.ready &&
      this.control.blueprintRegenerateError != null &&
      blueprintRegenerateErrorShowsRetry(this.control.blueprintRegenerateError)
    );
  }

  get fromPlanId(): number | null {
    const raw = this.route.snapshot.queryParamMap.get('fromPlan');
    if (raw == null) {
      return null;
    }
    const id = Number(raw);
    return id > 0 ? id : null;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const cropId = Number(this.route.snapshot.paramMap.get('id'));
    if (!cropId) {
      this.control = {
        ...initialControl,
        loading: false,
        taskTemplatesLoading: false,
        agriculturalTasksLoading: false,
        blueprintsLoading: false,
        error: this.translate.instant('crops.errors.invalid_id')
      };
      return;
    }
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
      taskTemplatesLoading: true,
      agriculturalTasksLoading: true,
      blueprintsLoading: true
    };
    this.loadTaskTemplatesUseCase.execute({ cropId });
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

  onSelectedTaskChange(taskId: number | null): void {
    this.control = { ...this.control, selectedAgriculturalTaskId: taskId };
  }

  onBlueprintStageChange(stageOrder: number | null): void {
    this.control = { ...this.control, selectedBlueprintStageOrder: stageOrder };
  }

  onBlueprintTaskChange(agriculturalTaskId: number | null): void {
    this.control = { ...this.control, selectedBlueprintAgriculturalTaskId: agriculturalTaskId };
  }

  onBlueprintGddCreateChange(value: number | null): void {
    this.control = { ...this.control, blueprintCreateGddTrigger: value };
  }

  createBlueprint(): void {
    const cropId = this.control.crop?.id;
    const agriculturalTaskId = this.control.selectedBlueprintAgriculturalTaskId;
    const stageOrder = this.control.selectedBlueprintStageOrder;
    const gddTrigger = this.control.blueprintCreateGddTrigger;
    if (
      !cropId ||
      agriculturalTaskId == null ||
      stageOrder == null ||
      gddTrigger == null ||
      Number.isNaN(gddTrigger)
    ) {
      return;
    }
    this.control = { ...this.control, blueprintCreating: true };
    this.createBlueprintUseCase.execute({
      cropId,
      agriculturalTaskId,
      stageOrder,
      stageName: this.blueprintStageNameForCreate,
      gddTrigger
    });
  }

  createTaskTemplate(): void {
    const cropId = this.control.crop?.id;
    const agriculturalTaskId = this.control.selectedAgriculturalTaskId;
    if (!cropId || !agriculturalTaskId) return;
    this.control = { ...this.control, taskTemplateCreating: true };
    this.createTaskTemplateUseCase.execute({ cropId, agriculturalTaskId });
  }

  deleteTaskTemplate(templateId: number): void {
    const cropId = this.control.crop?.id;
    if (!cropId) return;
    if (!confirm(this.translate.instant('crops.agricultural_tasks.index.actions.delete_confirm'))) return;
    this.deleteTaskTemplateUseCase.execute({ cropId, templateId });
  }

  regenerateBlueprints(): void {
    const cropId = this.control.crop?.id;
    if (!cropId) return;
    if (!confirm(this.translate.instant('crops.show.generate_task_schedule_blueprints_confirm'))) return;
    this.regenerateBlueprintsUseCase.execute({ cropId });
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
