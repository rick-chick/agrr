import { Component, DestroyRef, OnInit, inject } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { catchError, of, switchMap } from 'rxjs';
import { MasterContextHeaderComponent } from '../masters/master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../masters/master-context-header/master-context-crumb';
import { LoadPlanNewReadinessUseCase } from '../../usecase/plans/load-plan-new-readiness.usecase';
import { PRIVATE_PLAN_CREATE_GATEWAY } from '../../usecase/private-plan-create/private-plan-create-gateway';
import { buildOnboardingSteps, OnboardingStepView } from '../../domain/plans/onboarding-setup-steps';
import { ONBOARDING_PROVIDERS } from './onboarding.providers';

@Component({
  selector: 'app-onboarding',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule, MasterContextHeaderComponent],
  providers: [...ONBOARDING_PROVIDERS],
  template: `
    <div class="page-main">
      <app-master-context-header [crumbs]="contextCrumbs" />
      <header class="page-header">
        <h1 id="page-title" class="page-title">{{ 'onboarding.title' | translate }}</h1>
        <p class="page-description">{{ 'onboarding.subtitle' | translate }}</p>
      </header>
      <section class="section-card" aria-labelledby="page-title">
        @if (loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else if (error) {
          <p class="plan-new-error">{{ error }}</p>
        } @else {
          <ol class="onboarding-steps">
            @for (step of steps; track step.id) {
              <li class="onboarding-step" [class.onboarding-step--ready]="step.ready">
                <div class="onboarding-step__header">
                  <span class="onboarding-step__status" aria-hidden="true">{{ step.ready ? '✓' : '○' }}</span>
                  <h2 class="onboarding-step__title">{{ step.titleKey | translate }}</h2>
                </div>
                <p class="onboarding-step__description">{{ step.descriptionKey | translate }}</p>
                @if (!step.ready) {
                  <a class="btn btn-secondary onboarding-step__action" [routerLink]="step.routerLink">
                    {{ 'onboarding.step_action' | translate }}
                  </a>
                }
              </li>
            }
          </ol>
          <div class="onboarding-footer">
            <a routerLink="/plans/new" class="btn btn-primary">{{ 'onboarding.create_plan_cta' | translate }}</a>
          </div>
        }
      </section>
    </div>
  `,
  styleUrls: ['./onboarding.component.css']
})
export class OnboardingComponent implements OnInit {
  private readonly planCreateGateway = inject(PRIVATE_PLAN_CREATE_GATEWAY);
  private readonly loadReadinessUseCase = inject(LoadPlanNewReadinessUseCase);
  private readonly destroyRef = inject(DestroyRef);

  loading = true;
  error: string | null = null;
  steps: OnboardingStepView[] = [];

  get contextCrumbs(): MasterContextCrumb[] {
    return [
      { labelKey: 'plans.index.title', routerLink: ['/plans'] },
      { labelKey: 'onboarding.breadcrumb' }
    ];
  }

  ngOnInit(): void {
    this.planCreateGateway
      .fetchFarmsForPlanCreate()
      .pipe(
        switchMap((farms) => {
          const primaryFarm = farms.find((farm) => farm.hasValidFields) ?? farms[0];
          if (primaryFarm == null) {
            return of({ farms, readiness: null });
          }
          return this.loadReadinessUseCase
            .execute(primaryFarm.id, primaryFarm.fieldCount, primaryFarm.hasValidFields)
            .pipe(
              catchError(() => of(null)),
              switchMap((readiness) => of({ farms, readiness }))
            );
        }),
        takeUntilDestroyed(this.destroyRef),
        catchError((err: Error) => {
          this.error = err.message;
          this.loading = false;
          return of(null);
        })
      )
      .subscribe((result) => {
        if (result == null) {
          return;
        }
        this.steps = buildOnboardingSteps(result.farms, result.readiness);
        this.loading = false;
      });
  }
}
