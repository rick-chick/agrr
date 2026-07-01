import { Injectable, inject } from '@angular/core';
import { CreatePrivatePlanOutputPort } from '../../usecase/private-plan-create/create-private-plan.output-port';
import { CreatePrivatePlanResponseDto } from '../../usecase/private-plan-create/create-private-plan.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { Router } from '@angular/router';
import { pendingErrorFlashFromError } from '../../core/view-effects/pending-error-flash-presenter.helpers';
import { pendingSuccessFlashFromText } from '../../core/view-effects/pending-success-flash-presenter.helpers';
import { PlanNewView } from '../../components/plans/plan-new.view';

@Injectable()
export class CreatePrivatePlanPresenter implements CreatePrivatePlanOutputPort {
  private readonly router = inject(Router);
  private view: PlanNewView | null = null;

  setView(view: PlanNewView): void {
    this.view = view;
  }

  present(dto: CreatePrivatePlanResponseDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      submitting: false,
      error: null,
      pendingErrorFlash: null,
      pendingSuccessFlash: pendingSuccessFlashFromText('plans.messages.plan_created')
    };
    this.router.navigate(['/plans', dto.id]);
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      submitting: false,
      error: null,
      pendingSuccessFlash: null,
      pendingErrorFlash: pendingErrorFlashFromError(dto)
    };
  }
}
