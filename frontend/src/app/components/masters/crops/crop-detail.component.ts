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
import type { BlueprintDetailSummaryItem } from '../../../domain/crops/blueprint-detail-summary';

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
  blueprintSummary: null
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

        <section class="section-card" aria-labelledby="stages-heading">
          <h2 id="stages-heading" class="section-title">{{ 'crops.show.stages_title' | translate }}</h2>
          @if (control.crop.crop_stages?.length) {
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
          } @else {
            <p class="crop-detail__stages-empty">{{ 'crops.show.no_stages_description' | translate }}</p>
          }
          <a
            [routerLink]="['/crops', control.crop.id, 'stages']"
            class="btn-secondary crop-detail__stages-cta"
          >
            {{ 'crops.show.blueprint_readiness.stages_action' | translate }}
          </a>
        </section>

        <section class="section-card crop-detail__blueprint-summary" aria-labelledby="blueprints-summary-heading">
          <h2 id="blueprints-summary-heading" class="section-title">
            {{ 'crops.show.task_schedule_blueprints_title' | translate }}
          </h2>
          @if (control.blueprintsLoading) {
            <p class="master-loading">{{ 'common.loading' | translate }}</p>
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
            @if (control.blueprintSummary && control.blueprintCount === 0) {
              <p class="crop-detail__blueprint-summary-empty">
                {{ 'crops.show.no_task_schedule_blueprints' | translate }}
              </p>
            } @else if (control.blueprintSummary && control.blueprintSummary.lanes.length > 0) {
              <div class="blueprint-summary-grid">
                @for (lane of control.blueprintSummary!.lanes; track blueprintSummaryLaneId(lane)) {
                  <div class="blueprint-summary-card">
                    <h3 class="blueprint-summary-card__title">
                      @if (lane.stageOrder == null) {
                        {{ 'crops.show.blueprint_stage_lane.unassigned' | translate }}
                      } @else {
                        {{ lane.stageName }}
                      }
                    </h3>
                    @if (lane.stageOrder != null) {
                      @if (lane.gddRangeMissing) {
                        <p class="blueprint-summary-card__gdd-range blueprint-summary-card__gdd-range--warn">
                          {{ 'crops.show.blueprint_stage_lane.gdd_range_missing' | translate }}
                        </p>
                      } @else {
                        <p class="blueprint-summary-card__gdd-range">
                          {{
                            'crops.show.blueprint_stage_lane.gdd_range'
                              | translate: {
                                  start: lane.cumulativeGddStart,
                                  end: lane.cumulativeGddEnd
                                }
                          }}
                        </p>
                      }
                    } @else {
                      <p class="blueprint-summary-card__gdd-range blueprint-summary-card__gdd-range--warn">
                        {{ 'crops.show.blueprint_stage_lane.unassigned_hint' | translate }}
                      </p>
                    }
                    @if (
                      lane.stageOrder != null &&
                      lane.outOfRangeCount > 0 &&
                      !lane.gddRangeMissing
                    ) {
                      <p class="blueprint-summary-card__lane-warning" role="status">
                        {{
                          'crops.show.blueprint_stage_lane.out_of_range_count'
                            | translate: {
                                count: lane.outOfRangeCount,
                                start: lane.cumulativeGddStart,
                                end: lane.cumulativeGddEnd
                              }
                        }}
                      </p>
                    }
                    <ul class="blueprint-summary-card__tasks">
                      @for (item of lane.items; track item.id) {
                        <li
                          class="blueprint-summary-card__task"
                          [class.blueprint-summary-card__task--attention]="
                            item.gddError === 'out_of_range' || item.gddError === 'missing_stage'
                          "
                        >
                          @if (item.gddTrigger != null) {
                            <span>
                              {{
                                'crops.show.blueprint_summary.task_gdd_line'
                                  | translate: {
                                      taskName: blueprintSummaryTaskName(item),
                                      gdd: item.gddTrigger
                                    }
                              }}
                              {{ 'crops.show.gdd_unit' | translate }}
                            </span>
                          } @else if (item.gddError === 'gdd_required') {
                            <span>{{ blueprintSummaryTaskName(item) }}</span>
                            <span class="blueprint-summary-card__attention-badge" role="status">
                              {{ 'crops.show.blueprint_summary.timing_required' | translate }}
                            </span>
                          } @else {
                            <span>{{ blueprintSummaryTaskName(item) }}</span>
                            <span class="blueprint-summary-card__unset-badge" role="status">
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
            <a
              [routerLink]="['/crops', control.crop.id, 'task_schedule_blueprints']"
              class="btn-primary crop-detail__blueprint-summary-cta"
            >
              {{ 'crops.show.blueprint_summary.edit_action' | translate }}
            </a>
          }
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

  blueprintSummaryLaneId(lane: { stageOrder: number | null }): string {
    return lane.stageOrder == null ? 'unassigned' : String(lane.stageOrder);
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
