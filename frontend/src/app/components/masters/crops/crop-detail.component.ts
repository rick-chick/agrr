import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { CropDetailView, CropDetailViewState } from './crop-detail.view';
import { LoadCropDetailUseCase } from '../../../usecase/crops/load-crop-detail.usecase';
import { DeleteCropUseCase } from '../../../usecase/crops/delete-crop.usecase';
import { LoadCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/load-crop-task-schedule-blueprints.usecase';
import {
  CropDetailPresenter,
  CROP_DETAIL_PROVIDERS
} from '../../../usecase/crops/crop-detail.providers';
import { UndoToastService } from '../../../services/undo-toast.service';
import { applyPendingUndoToastViewEffects } from '../../../core/view-effects/pending-undo-toast-view.effects';
import { FlashMessageService } from '../../../services/flash-message.service';
import { applyPendingFlashViewEffects } from '../../../core/view-effects/pending-success-flash-view.effects';
import { formatIsoDateTimeForDisplay } from '../../../core/format-display-date';
import { defaultBlueprintReadiness } from '../../../domain/crops/blueprint-generation-readiness';
import type {
  BlueprintDetailSummaryGddGroup,
  BlueprintDetailSummaryItem
} from '../../../domain/crops/blueprint-detail-summary';
import {
  shouldShowBlueprintSummaryGddGroupLabel,
  blueprintDetailSummaryItemNeedsAttention as domainBlueprintDetailSummaryItemNeedsAttention
} from '../../../domain/crops/blueprint-detail-summary';
import type { CropDetailStageColumn } from '../../../domain/crops/crop-detail-stage-board';
import {
  gddAxisTotalGdd,
  type CumulativeGddTimelineSegment
} from '../../../domain/crops/cumulative-gdd-timeline';

const initialControl: CropDetailViewState = {
  loading: true,
  error: null,
  crop: null,
  pendingUndoToast: null,
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  blueprintsLoading: true,
  blueprintCount: 0,
  blueprintReadiness: defaultBlueprintReadiness(),
  blueprintSummary: null,
  stageBoardColumns: [],
  cumulativeGddTimelineSegments: []
};

@Component({
  selector: 'app-crop-detail',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [...CROP_DETAIL_PROVIDERS],
  template: `
    <main class="page-main">
      @if (control.loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (control.error) {
        <p class="master-loading master-error">{{ control.error }}</p>
      } @else if (control.crop) {
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
            <a [routerLink]="['/crops']" class="btn-secondary">{{ 'common.back' | translate }}</a>
            <button type="button" class="btn-danger" (click)="deleteCrop()">{{ 'common.delete' | translate }}</button>
          </div>
        </section>

        <section class="section-card crop-detail__cultivation-template" aria-labelledby="cultivation-template-heading">
          <h2 id="cultivation-template-heading" class="section-title">
            {{ 'crops.show.cultivation_template_title' | translate }}
          </h2>
          <p class="section-card__description crop-detail__cultivation-lead">
            {{ 'crops.show.task_schedule_blueprints_lead' | translate }}
          </p>

          @if (!control.blueprintsLoading) {
            <div class="blueprint-readiness" role="status">
              <p class="blueprint-readiness__title">
                {{ 'crops.show.blueprint_readiness.detail_title' | translate }}
              </p>
              <ul class="blueprint-readiness__list">
                <li [class.blueprint-readiness__item--ok]="control.blueprintReadiness.stageRequirementsReady">
                  @if (control.blueprintReadiness.stageRequirementsReady) {
                    <span>{{ 'crops.show.blueprint_readiness.stages_ready' | translate }}</span>
                  } @else {
                    <span>{{ 'crops.show.blueprint_readiness.stages_missing' | translate }}</span>
                  }
                </li>
                <li [class.blueprint-readiness__item--ok]="control.blueprintReadiness.blueprintsReady">
                  @if (control.blueprintReadiness.blueprintsReady) {
                    <span>{{ 'crops.show.blueprint_readiness.blueprints_ready' | translate }}</span>
                  } @else {
                    <span>{{ 'crops.show.blueprint_readiness.blueprints_missing' | translate }}</span>
                  }
                </li>
              </ul>
            </div>
          }

          @if (control.blueprintsLoading) {
            <p class="master-loading">{{ 'common.loading' | translate }}</p>
          } @else if (!control.crop.crop_stages?.length) {
            <p class="crop-detail__stages-empty">{{ 'crops.show.no_stages_description' | translate }}</p>
          } @else {
            <p class="crop-detail__blueprint-summary-count">
              {{
                'crops.show.blueprint_summary.count'
                  | translate: { count: control.blueprintCount }
              }}
              @if (control.blueprintSummary && control.blueprintSummary.attentionCount > 0) {
                <span class="crop-detail__blueprint-summary-attention">
                  {{
                    'crops.show.blueprint_summary.attention_suffix'
                      | translate: { count: control.blueprintSummary.attentionCount }
                  }}
                </span>
              }
            </p>
            @if (!control.blueprintReadiness.ready) {
              <p class="crop-detail__blueprint-summary-hint" role="status">
                {{ 'crops.show.blueprint_summary.setup_required' | translate }}
              </p>
            }
            @if (control.cumulativeGddTimelineSegments.length) {
              <div
                class="blueprint-gdd-axis"
                role="img"
                [attr.aria-label]="
                  'crops.show.task_schedule_blueprints_gdd_axis_label'
                    | translate: {
                        total: gddAxisTotal(control.cumulativeGddTimelineSegments)
                      }
                "
              >
                <p class="blueprint-gdd-axis__caption">
                  {{ 'crops.show.task_schedule_blueprints_gdd_axis_caption' | translate }}
                </p>
                <div class="blueprint-gdd-axis__bar">
                  @for (
                    segment of control.cumulativeGddTimelineSegments;
                    track segment.stageOrder
                  ) {
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
              class="crop-detail__stage-board"
              role="list"
              [attr.aria-label]="'crops.show.blueprint_stage_lane.board_label' | translate"
            >
              @for (column of control.stageBoardColumns; track stageBoardColumnId(column)) {
                <div class="crop-detail__stage-column" role="listitem">
                  <h3 class="crop-detail__stage-column-title">
                    @if (column.stageOrder == null) {
                      {{ 'crops.show.blueprint_stage_lane.unassigned' | translate }}
                    } @else {
                      {{ column.stageName }}
                    }
                  </h3>
                  @if (column.stageOrder != null) {
                    <div class="crop-detail__stage-requirements">
                      @if (column.requiredGdd != null) {
                        <p class="crop-detail__stage-requirement">
                          <strong>{{ 'crops.show.stage_required_gdd_label' | translate }}:</strong>
                          {{ column.requiredGdd }} {{ 'crops.show.gdd_unit' | translate }}
                        </p>
                      }
                      @if (column.optimalMin != null && column.optimalMax != null) {
                        <p class="crop-detail__stage-requirement">
                          <strong>{{ 'crops.show.optimal_temperature' | translate }}:</strong>
                          {{ column.optimalMin }}{{ 'crops.show.celsius_unit' | translate }}
                          - {{ column.optimalMax }}{{ 'crops.show.celsius_unit' | translate }}
                        </p>
                      }
                    </div>
                    @if (column.gddRangeMissing) {
                      <p class="crop-detail__stage-cumulative-range crop-detail__stage-cumulative-range--warn">
                        {{ 'crops.show.blueprint_stage_lane.gdd_range_missing' | translate }}
                      </p>
                    } @else if (
                      column.cumulativeGddStart != null && column.cumulativeGddEnd != null
                    ) {
                      <p class="crop-detail__stage-cumulative-range">
                        {{
                          'crops.show.blueprint_stage_lane.gdd_range'
                            | translate: {
                                start: column.cumulativeGddStart,
                                end: column.cumulativeGddEnd
                              }
                        }}
                      </p>
                    }
                  } @else {
                    <p class="crop-detail__stage-cumulative-range crop-detail__stage-cumulative-range--warn">
                      {{ 'crops.show.blueprint_stage_lane.unassigned_hint' | translate }}
                    </p>
                  }
                  @if (
                    column.stageOrder != null &&
                    column.outOfRangeCount > 0 &&
                    !column.gddRangeMissing
                  ) {
                    <p class="crop-detail__stage-lane-warning" role="status">
                      {{
                        'crops.show.blueprint_stage_lane.out_of_range_count'
                          | translate: {
                              count: column.outOfRangeCount,
                              start: column.cumulativeGddStart,
                              end: column.cumulativeGddEnd
                            }
                      }}
                    </p>
                  }
                  @if (column.gddGroups.length === 0) {
                    <p class="crop-detail__stage-tasks-empty">
                      {{ 'crops.show.blueprint_summary.empty_on_detail' | translate }}
                    </p>
                  } @else {
                    <div class="crop-detail__stage-task-groups">
                      @for (
                        group of column.gddGroups;
                        track blueprintSummaryGddGroupId(group, $index)
                      ) {
                        <div class="crop-detail__stage-task-group">
                          @if (showBlueprintSummaryGddGroupLabel(column, group)) {
                            <p class="crop-detail__stage-task-group-label">
                              @if (group.gddTrigger != null) {
                                {{ group.gddTrigger }}{{ 'crops.show.gdd_unit' | translate }}
                              }
                            </p>
                          }
                          <ul class="crop-detail__stage-task-badges" role="list">
                            @for (item of group.items; track item.id) {
                              <li
                                class="crop-detail__stage-task-badge"
                                [class.crop-detail__stage-task-badge--attention]="
                                  blueprintDetailSummaryItemNeedsAttention(item)
                                "
                              >
                                <span class="crop-detail__stage-task-badge-label">
                                  {{ blueprintSummaryTaskName(item) }}
                                </span>
                                @if (item.gddError === 'gdd_required') {
                                  <span class="crop-detail__stage-task-badge-status" role="status">
                                    {{
                                      'crops.show.blueprint_summary.timing_required' | translate
                                    }}
                                  </span>
                                } @else if (
                                  item.gddTrigger == null && item.gddError == null
                                ) {
                                  <span class="crop-detail__stage-task-badge-status" role="status">
                                    {{ 'crops.show.blueprint_gdd_unset' | translate }}
                                  </span>
                                }
                              </li>
                            }
                          </ul>
                        </div>
                      }
                    </div>
                  }
                </div>
              }
            </div>
          }

          <div class="crop-detail__cultivation-actions">
            <a
              [routerLink]="['/crops', control.crop.id, 'stages']"
              class="btn-secondary"
            >
              {{
                (control.blueprintReadiness.stageRequirementsReady
                  ? 'crops.show.blueprint_readiness.stages_edit_action'
                  : 'crops.show.blueprint_readiness.stages_action')
                  | translate
              }}
            </a>
            <a
              [routerLink]="['/crops', control.crop.id, 'task_schedule_blueprints']"
              class="btn-secondary"
            >
              {{ 'crops.show.blueprint_summary.edit_action' | translate }}
            </a>
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
  private readonly loadBlueprintsUseCase = inject(LoadCropTaskScheduleBlueprintsUseCase);
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
      applyPendingFlashViewEffects(value, {
        flash: this.flashMessage
      }),
      { toast: this.undoToast }
    );
    this._control = next;
    this.cdr.markForCheck();
  }

  displayDateTime(value: string): string {
    return formatIsoDateTimeForDisplay(value, this.translate.currentLang);
  }

  stageBoardColumnId(column: CropDetailStageColumn): string {
    return column.stageOrder == null ? 'unassigned' : String(column.stageOrder);
  }

  gddAxisTotal(segments: CumulativeGddTimelineSegment[]): number {
    return gddAxisTotalGdd(segments);
  }

  showBlueprintSummaryGddGroupLabel(
    column: CropDetailStageColumn,
    group: BlueprintDetailSummaryGddGroup
  ): boolean {
    return shouldShowBlueprintSummaryGddGroupLabel(column, group);
  }

  blueprintDetailSummaryItemNeedsAttention(item: BlueprintDetailSummaryItem): boolean {
    return domainBlueprintDetailSummaryItemNeedsAttention(item);
  }

  blueprintSummaryGddGroupId(
    group: BlueprintDetailSummaryGddGroup,
    index: number
  ): string {
    const gddId = group.gddTrigger == null ? 'unset' : String(group.gddTrigger);
    const firstItemId = group.items[0]?.id ?? index;
    return `${gddId}-${firstItemId}`;
  }

  blueprintSummaryTaskName(item: BlueprintDetailSummaryItem): string {
    return item.taskName?.trim() || this.translate.instant('crops.show.unnamed_blueprint');
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const cropId = Number(this.route.snapshot.paramMap.get('id'));
    if (!cropId) {
      this.control = {
        ...initialControl,
        loading: false,
        blueprintsLoading: false,
        error: this.translate.instant('crops.errors.invalid_id')
      };
      return;
    }
    this.load(cropId);
  }

  load(cropId: number): void {
    this.control = { ...this.control, loading: true, blueprintsLoading: true };
    this.useCase.execute({ cropId });
    this.loadBlueprintsUseCase.execute({ cropId });
  }

  reload(): void {
    const cropId = Number(this.route.snapshot.paramMap.get('id'));
    if (cropId) {
      this.load(cropId);
    }
  }

  deleteCrop(): void {
    if (!this.control.crop) return;
    this.deleteUseCase.execute({
      cropId: this.control.crop.id,
      onSuccess: () => this.router.navigate(['/crops'])
    });
  }
}
