import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { PlanDisplayNamePipe } from '../../core/plan-display-name.pipe';
import { PlanGanttClimateShellComponent } from './plan-gantt-climate-shell.component';
import { PlanDetailView, PlanDetailViewState } from './plan-detail.view';
import { LoadPlanDetailUseCase } from '../../usecase/plans/load-plan-detail.usecase';
import { PlanDetailPresenter, PLAN_DETAIL_PROVIDERS } from '../../usecase/plans/plan-detail.providers';

const initialControl: PlanDetailViewState = {
  loading: true,
  error: null,
  plan: null,
  planData: null
};

@Component({
  selector: 'app-plan-detail',
  standalone: true,
  imports: [
    CommonModule,
    RouterLink,
    PlanGanttClimateShellComponent,
    TranslateModule,
    PlanDisplayNamePipe
  ],
  providers: [...PLAN_DETAIL_PROVIDERS],
  template: `
    <main class="page-main">
      <a class="plan-detail__back" [routerLink]="['/plans']">{{
        'plans.show.back_to_list' | translate
      }}</a>
      @if (control.loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (control.error) {
        <div class="plan-detail__alert" role="alert">
          <p>{{ control.error | translate }}</p>
        </div>
      } @else if (control.plan) {
        <h2 class="plan-detail__title">{{ control.plan.name | planDisplayName }}</h2>
        @if (control.planData) {
          <div class="plan-detail__body plan-detail-surface">
            <app-plan-gantt-climate-shell [data]="control.planData" [planType]="planType" />
          </div>
        }
      }
    </main>
  `,
  styleUrls: ['./plan-detail.component.css']
})
export class PlanDetailComponent implements PlanDetailView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly useCase = inject(LoadPlanDetailUseCase);
  private readonly presenter = inject(PlanDetailPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: PlanDetailViewState = initialControl;
  get control(): PlanDetailViewState {
    return this._control;
  }
  set control(value: PlanDetailViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  readonly planType: 'private' | 'public' = 'private';

  ngOnInit(): void {
    this.presenter.setView(this);
    const planId = Number(this.route.snapshot.paramMap.get('id'));
    if (!planId) {
      this.control = {
        ...initialControl,
        loading: false,
        error: 'plans.errors.invalid_id'
      };
      return;
    }
    this.load(planId);
  }

  load(planId: number): void {
    this.control = { ...this.control, loading: true };
    this.useCase.execute({ planId });
  }
}
