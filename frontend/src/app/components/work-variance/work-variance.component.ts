import { ChangeDetectorRef, Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { WorkVariancePresenter } from '../../adapters/work-variance/work-variance.presenter';
import { WORK_VARIANCE_PROVIDERS } from '../../usecase/work-variance/work-variance.providers';
import { WorkVarianceInitUseCase } from '../../usecase/work-variance/work-variance-init.usecase';
import type { VariancePortfolioFilters } from '../../domain/work-variance-portfolio/variance-portfolio-filters';
import {
  initialWorkVarianceViewState,
  WorkVarianceView,
  WorkVarianceViewState
} from './work-variance.view';

@Component({
  selector: 'app-work-variance',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [...WORK_VARIANCE_PROVIDERS],
  template: `
    <div class="page-main">
      <header class="page-header">
        <h1 id="page-title" class="page-title">{{ 'work.variance.title' | translate }}</h1>
        @if (control.error) {
          <p class="page-description">{{ 'work.variance.error_subtitle' | translate }}</p>
        } @else {
          <p class="page-description">{{ 'work.variance.subtitle' | translate }}</p>
        }
      </header>

      @if (!control.loading && control.portfolioSummary && control.rows.length) {
        <section
          class="work-variance__portfolio-summary"
          role="status"
          aria-labelledby="work-variance-portfolio-summary-title"
        >
          <h2 id="work-variance-portfolio-summary-title" class="work-variance__portfolio-summary-title">
            {{ 'work.variance.portfolio_summary.title' | translate }}
          </h2>
          <dl class="work-variance__portfolio-summary-grid">
            <div>
              <dt>{{ 'work.variance.portfolio_summary.unrecorded' | translate }}</dt>
              <dd>{{ control.portfolioSummary.unrecordedCount }}</dd>
            </div>
            <div>
              <dt>{{ 'work.variance.portfolio_summary.action_required' | translate }}</dt>
              <dd>{{ control.portfolioSummary.actionRequiredCount }}</dd>
            </div>
            <div>
              <dt>{{ 'work.variance.portfolio_summary.gdd_delay' | translate }}</dt>
              <dd>{{ control.portfolioSummary.gddDelayCount }}</dd>
            </div>
            <div>
              <dt>{{ 'work.variance.portfolio_summary.threshold_exceeded' | translate }}</dt>
              <dd>{{ control.portfolioSummary.daysThresholdExceededCount }}</dd>
            </div>
          </dl>
        </section>
      }

      @if (!control.loading && control.rows.length) {
        <section class="work-variance__filters" aria-labelledby="work-variance-filters-title">
          <h2 id="work-variance-filters-title" class="work-variance__filters-title">
            {{ 'work.variance.filters.title' | translate }}
          </h2>
          <div class="work-variance__filters-grid">
            <label class="work-variance__filter">
              <span>{{ 'work.variance.filters.farm' | translate }}</span>
              <select
                [value]="farmFilterValue"
                (change)="onFarmFilterChange($event)"
              >
                <option value="">{{ 'work.variance.filters.all' | translate }}</option>
                @for (farm of control.filterOptions.farms; track farm.farmId) {
                  <option [value]="farm.farmId">{{ farm.farmName }}</option>
                }
              </select>
            </label>
            <label class="work-variance__filter">
              <span>{{ 'work.variance.filters.status' | translate }}</span>
              <select
                [value]="statusFilterValue"
                (change)="onStatusFilterChange($event)"
              >
                <option value="">{{ 'work.variance.filters.all' | translate }}</option>
                @for (status of control.filterOptions.statuses; track status) {
                  <option [value]="status">{{ statusLabel(status) | translate }}</option>
                }
              </select>
            </label>
            <label class="work-variance__filter">
              <span>{{ 'work.variance.filters.year' | translate }}</span>
              <select
                [value]="yearFilterValue"
                (change)="onYearFilterChange($event)"
              >
                <option value="">{{ 'work.variance.filters.all' | translate }}</option>
                @for (year of control.filterOptions.planYears; track year) {
                  <option [value]="year">{{ year }}</option>
                }
              </select>
            </label>
          </div>
        </section>
      }

      @if (!control.loading && control.attentionList?.items?.length) {
        <section class="work-variance__attention-list" aria-labelledby="work-variance-attention-list-title">
          <h2 id="work-variance-attention-list-title" class="work-variance__attention-list-title">
            {{ 'work.variance.attention_list.title' | translate }}
          </h2>
          <ul class="work-variance__attention-list-items" role="list">
            @for (item of control.attentionList!.items; track item.itemId) {
              <li class="work-variance__attention-list-item">
                <a
                  class="work-variance__attention-list-link"
                  [routerLink]="['/plans', item.planId, item.linkTarget]"
                >
                  {{
                    'work.variance.attention_list.item'
                      | translate: { farm: item.farmName, task: item.taskName }
                  }}
                </a>
              </li>
            }
          </ul>
        </section>
      }

      <section class="section-card" aria-labelledby="page-title">
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else if (control.error) {
          <div class="page-alert-error work-variance__error" role="alert">
            <p>{{ control.error | translate }}</p>
            <button type="button" class="btn btn-secondary work-variance__retry" (click)="reload()">
              {{ 'work.variance.retry' | translate }}
            </button>
          </div>
        } @else if (!control.rows.length) {
          <div class="work-variance-empty">
            <p>{{ 'work.variance.no_plans' | translate }}</p>
            <p class="work-variance-empty-hint">{{ 'work.variance.no_plans_hint' | translate }}</p>
            <a routerLink="/plans/new" class="btn btn-primary">{{ 'work.variance.create_plan_link' | translate }}</a>
          </div>
        } @else if (!control.farmGroups.length) {
          <p class="work-variance__no-results">{{ 'work.variance.no_filter_results' | translate }}</p>
        } @else {
          @for (group of control.farmGroups; track group.farmId) {
            <section class="work-variance__farm-group" [attr.aria-label]="group.farmName">
              <h2 class="work-variance__farm-title">{{ group.farmName }}</h2>
              <div class="work-variance__table-wrap">
                <table class="work-variance__table">
                  <thead>
                    <tr>
                      <th scope="col">{{ 'work.variance.table.year' | translate }}</th>
                      <th scope="col">{{ 'work.variance.table.status' | translate }}</th>
                      <th scope="col">{{ 'work.variance.table.unrecorded' | translate }}</th>
                      <th scope="col">{{ 'work.variance.table.gdd_delay' | translate }}</th>
                      <th scope="col">{{ 'work.variance.table.threshold_exceeded' | translate }}</th>
                      <th scope="col">{{ 'work.variance.table.actions' | translate }}</th>
                    </tr>
                  </thead>
                  <tbody>
                    @for (plan of group.plans; track plan.planId) {
                      <tr>
                        <td>{{ plan.planYear ?? '—' }}</td>
                        <td>{{ statusLabel(plan.status) | translate }}</td>
                        <td>{{ plan.unrecordedCount }}</td>
                        <td>{{ plan.gddDelayCount }}</td>
                        <td>{{ plan.thresholdExceededCount }}</td>
                        <td class="work-variance__actions">
                          <a
                            class="btn btn-secondary work-variance__action-link"
                            [routerLink]="['/plans', plan.planId, 'work']"
                          >
                            {{ 'work.variance.table.work_link' | translate }}
                          </a>
                          <a
                            class="btn btn-secondary work-variance__action-link"
                            [routerLink]="['/plans', plan.planId, 'learn']"
                          >
                            {{ 'work.variance.table.learn_link' | translate }}
                          </a>
                          <a
                            class="btn btn-secondary work-variance__action-link"
                            [routerLink]="['/plans', plan.planId]"
                          >
                            {{ 'work.variance.table.plan_link' | translate }}
                          </a>
                        </td>
                      </tr>
                    }
                  </tbody>
                </table>
              </div>
            </section>
          }
        }
      </section>
    </div>
  `,
  styleUrls: ['./work-variance.component.css']
})
export class WorkVarianceComponent implements WorkVarianceView, OnInit {
  private readonly initUseCase = inject(WorkVarianceInitUseCase);
  private readonly presenter = inject(WorkVariancePresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: WorkVarianceViewState = initialWorkVarianceViewState;
  get control(): WorkVarianceViewState {
    return this._control;
  }
  set control(value: WorkVarianceViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  get farmFilterValue(): string {
    return this.control.filters.farmId?.toString() ?? '';
  }

  get statusFilterValue(): string {
    return this.control.filters.status ?? '';
  }

  get yearFilterValue(): string {
    return this.control.filters.planYear?.toString() ?? '';
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.reload();
  }

  reload(): void {
    this.control = {
      ...this.control,
      loading: true,
      error: null
    };
    this.initUseCase.execute();
  }

  onFarmFilterChange(event: Event): void {
    const value = (event.target as HTMLSelectElement).value;
    this.applyFilters({
      ...this.control.filters,
      farmId: value ? Number(value) : null
    });
  }

  onStatusFilterChange(event: Event): void {
    const value = (event.target as HTMLSelectElement).value;
    this.applyFilters({
      ...this.control.filters,
      status: value || null
    });
  }

  onYearFilterChange(event: Event): void {
    const value = (event.target as HTMLSelectElement).value;
    this.applyFilters({
      ...this.control.filters,
      planYear: value ? Number(value) : null
    });
  }

  statusLabel(status: string): string {
    const key = `work.variance.status.${status}`;
    return key;
  }

  private applyFilters(filters: VariancePortfolioFilters): void {
    this.initUseCase.applyFilters(filters);
  }
}
