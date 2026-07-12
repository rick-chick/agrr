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
  pendingSuccessFlash: null,
  pendingNavigation: null
};

@Component({
  selector: 'app-work-hub',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [...WORK_HUB_PROVIDERS],
  template: `
    <main class="page-main">
      <header class="page-header">
        <h1 id="page-title" class="page-title">{{ 'work.hub.title' | translate }}</h1>
        @if (control.error) {
          <p class="page-description">{{ 'work.hub.error_subtitle' | translate }}</p>
        } @else {
          <p class="page-description">{{ 'work.hub.subtitle' | translate }}</p>
        }
      </header>

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
                      <span class="item-card__title">{{ farm.farmName }}</span>
                      <span class="work-hub__meta">
                        {{
                          'work.hub.farm_meta'
                            | translate: { count: farm.fieldCount, area: farm.totalArea }
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
    </main>
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
