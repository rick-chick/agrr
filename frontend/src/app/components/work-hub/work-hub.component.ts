import { ChangeDetectorRef, Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { WorkHubPresenter } from '../../adapters/work-hub/work-hub.presenter';
import { EnsurePlanForFarmUseCase } from '../../usecase/work-hub/ensure-plan-for-farm.usecase';
import { WorkHubInitUseCase } from '../../usecase/work-hub/work-hub-init.usecase';
import { WORK_HUB_PROVIDERS } from '../../usecase/work-hub/work-hub.providers';
import { FlashMessageService } from '../../services/flash-message.service';
import { applyPendingSuccessFlashViewEffects } from '../../core/view-effects/pending-success-flash-view.effects';
import { applyPendingNavigationViewEffects } from '../../core/view-effects/pending-navigation-view.effects';
import { WorkHubView, WorkHubViewState } from './work-hub.view';

const initialControl: WorkHubViewState = {
  loading: true,
  submitting: false,
  error: null,
  farms: [],
  portfolioSummary: null,
  varianceCoverage: null,
  attentionList: null,
  pendingSuccessFlash: null,
  pendingNavigation: null
};

@Component({
  selector: 'app-work-hub',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [...WORK_HUB_PROVIDERS],
  template: `
    <div class="page-main">
      <header class="page-header">
        <h1 id="page-title" class="page-title">{{ 'work.hub.title' | translate }}</h1>
        @if (control.error) {
          <p class="page-description">{{ 'work.hub.error_subtitle' | translate }}</p>
        } @else {
          <p class="page-description">{{ 'work.hub.subtitle' | translate }}</p>
        }
      </header>

      @if (!control.loading && control.portfolioSummary && control.farms.length) {
        <section
          class="work-hub__portfolio-summary"
          role="status"
          aria-labelledby="work-hub-portfolio-summary-title"
        >
          <h2 id="work-hub-portfolio-summary-title" class="work-hub__portfolio-summary-title">
            {{ 'work.hub.portfolio_summary.title' | translate }}
          </h2>
          <dl class="work-hub__portfolio-summary-grid">
            <div>
              <dt>{{ 'work.hub.portfolio_summary.unrecorded' | translate }}</dt>
              <dd>{{ control.portfolioSummary.unrecordedCount }}</dd>
            </div>
            <div>
              <dt>{{ 'work.hub.portfolio_summary.action_required' | translate }}</dt>
              <dd>{{ control.portfolioSummary.actionRequiredCount }}</dd>
            </div>
            <div>
              <dt>{{ 'work.hub.portfolio_summary.gdd_delay' | translate }}</dt>
              <dd>{{ control.portfolioSummary.gddDelayCount }}</dd>
            </div>
            <div>
              <dt>{{ 'work.hub.portfolio_summary.threshold_exceeded' | translate }}</dt>
              <dd>{{ control.portfolioSummary.daysThresholdExceededCount }}</dd>
            </div>
          </dl>
          @if (control.varianceCoverage) {
            <p class="work-hub__variance-coverage">
              {{
                'work.hub.portfolio_summary.variance_coverage'
                  | translate
                    : {
                        farms: control.varianceCoverage.farmCount,
                        plans: control.varianceCoverage.planCount
                      }
              }}
            </p>
          }
          <a routerLink="/work/variance" class="btn btn-secondary work-hub__variance-link">
            {{ 'work.hub.portfolio_summary.view_variance_portfolio' | translate }}
          </a>
        </section>
      }

      @if (!control.loading && control.attentionList?.items?.length) {
        <section
          class="work-hub__attention-list"
          aria-labelledby="work-hub-attention-list-title"
        >
          <h2 id="work-hub-attention-list-title" class="work-hub__attention-list-title">
            {{ 'work.hub.attention_list.title' | translate }}
          </h2>
          <ul class="work-hub__attention-list-items" role="list">
            @for (item of control.attentionList!.items; track item.itemId) {
              <li class="work-hub__attention-list-item">
                <a
                  class="work-hub__attention-list-link"
                  [routerLink]="['/plans', item.planId, item.linkTarget]"
                >
                  @if (item.kind === 'weather_trigger') {
                    {{
                      'work.hub.attention_list.weather_trigger_item'
                        | translate
                          : {
                              farm: item.farmName,
                              count: item.weatherTriggerCount
                            }
                    }}
                    @for (triggerType of item.weatherTriggerTypes; track triggerType) {
                      <span class="work-hub__attention-list-badge">
                        {{
                          'plans.work.today_attention.weather_trigger.' + triggerType
                            | translate
                        }}
                      </span>
                    }
                  } @else {
                    {{
                      'work.hub.attention_list.item'
                        | translate: { farm: item.farmName, task: item.taskName }
                    }}
                  }
                </a>
              </li>
            }
          </ul>
        </section>
      }

      <section class="section-card" aria-labelledby="page-title">
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else {
          @if (control.submitting) {
            <p class="work-hub__submitting master-loading" role="status">
              @if (submittingFarmName) {
                {{ 'work.hub.creating_plan_for' | translate: { name: submittingFarmName } }}
              } @else {
                {{ 'work.hub.creating_plan' | translate }}
              }
            </p>
          }

          @if (control.error) {
            <div class="page-alert-error work-hub__error" role="alert">
              <p>{{ control.error | translate }}</p>
              <button type="button" class="btn btn-secondary work-hub__retry" (click)="reload()">
                {{ 'work.hub.retry' | translate }}
              </button>
            </div>
          }

          @if (!control.farms.length && !control.error) {
            <div class="work-hub-empty">
              <p>{{ 'work.hub.no_farms' | translate }}</p>
              <p class="work-hub-empty-hint">{{ 'work.hub.no_farms_hint' | translate }}</p>
              <a routerLink="/farms/new" class="btn btn-primary">{{ 'work.hub.create_farm_link' | translate }}</a>
            </div>
          } @else if (control.farms.length) {
            <h2 class="work-hub__section-title">{{ 'work.hub.select_farm' | translate }}</h2>
            <ul class="card-list" role="list">
              @for (farm of control.farms; track farm.farmId) {
                <li class="card-list__item">
                  <article class="item-card">
                    <button
                      type="button"
                      class="item-card__body work-hub__farm-btn"
                      [disabled]="!farm.hasValidFields || control.submitting"
                      (click)="selectFarm(farm)"
                    >
                      <span class="item-card__title">
                        {{ farm.farmName }}
                        @if (farm.thresholdExceededCount > 0) {
                          <span
                            class="work-hub__context-badge"
                            [attr.aria-label]="
                              'work.hub.context_attention_badge_aria'
                                | translate: { count: farm.thresholdExceededCount }
                            "
                          >
                            {{ 'work.hub.context_attention_badge' | translate }}
                          </span>
                        }
                        @if (farm.otherVariancePlanCount > 0) {
                          <span
                            class="work-hub__other-plans-badge"
                            [attr.aria-label]="
                              'work.hub.other_plans_badge_aria'
                                | translate: { count: farm.otherVariancePlanCount }
                            "
                          >
                            {{
                              'work.hub.other_plans_badge'
                                | translate: { count: farm.otherVariancePlanCount }
                            }}
                          </span>
                        }
                      </span>
                      <span class="work-hub__meta">
                        {{
                          'work.hub.farm_meta'
                            | translate: { count: farm.fieldCount, area: farm.totalArea }
                        }}
                      </span>
                      <span class="work-hub__summary">
                        {{
                          'work.hub.overdue_summary'
                            | translate: { count: farm.overdueCount }
                        }}
                        ·
                        {{
                          'work.hub.today_summary'
                            | translate: { count: farm.todayCount }
                        }}
                        ·
                        {{
                          'work.hub.unrecorded_summary'
                            | translate: { count: farm.unrecordedCount }
                        }}
                        ·
                        {{
                          'work.hub.gdd_delay_summary'
                            | translate: { count: farm.gddDelayCount }
                        }}
                        ·
                        {{
                          'work.hub.threshold_exceeded_summary'
                            | translate: { count: farm.thresholdExceededCount }
                        }}
                      </span>
                      <span class="work-hub__cta">
                        {{
                          farm.planId
                            ? ('work.hub.open_work' | translate)
                            : ('work.hub.start_recording' | translate)
                        }}
                      </span>
                    </button>
                  </article>
                  @if (!farm.hasValidFields) {
                    <p class="work-hub__warning">
                      {{ 'work.hub.no_fields_warning' | translate }}
                      <a [routerLink]="['/farms', farm.farmId]">{{ 'work.hub.register_fields_link' | translate }}</a>
                    </p>
                  }
                </li>
              }
            </ul>
          }
        }
      </section>
    </div>
  `,
  styleUrls: ['./work-hub.component.css']
})
export class WorkHubComponent implements WorkHubView, OnInit {
  private readonly initUseCase = inject(WorkHubInitUseCase);
  private readonly ensureUseCase = inject(EnsurePlanForFarmUseCase);
  private readonly presenter = inject(WorkHubPresenter);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly router = inject(Router);
  private readonly cdr = inject(ChangeDetectorRef);

  selectedFarmName: string | null = null;

  get submittingFarmName(): string | null {
    if (this.selectedFarmName) {
      return this.selectedFarmName;
    }
    if (this.control.farms.length === 1) {
      return this.control.farms[0].farmName;
    }
    return null;
  }

  private _control: WorkHubViewState = initialControl;
  get control(): WorkHubViewState {
    return this._control;
  }
  set control(value: WorkHubViewState) {
    const withFlash = applyPendingSuccessFlashViewEffects(value, { flash: this.flashMessage });
    this._control = applyPendingNavigationViewEffects(withFlash, { router: this.router });
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.reload();
  }

  reload(): void {
    this.selectedFarmName = null;
    this.control = {
      ...this.control,
      loading: true,
      submitting: false,
      error: null
    };
    this.initUseCase.execute();
  }

  selectFarm(farm: WorkHubViewState['farms'][number]): void {
    if (!farm.hasValidFields || this.control.submitting) return;
    this.selectedFarmName = farm.farmName;
    this.control = { ...this.control, submitting: true, error: null };
    this.ensureUseCase.execute({
      farmId: farm.farmId,
      existingPlanId: farm.planId
    });
  }
}
