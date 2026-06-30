import { HttpErrorResponse } from '@angular/common/http';
import { Inject, Injectable } from '@angular/core';
import { catchError, of, switchMap, throwError } from 'rxjs';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { PLAN_GATEWAY, PlanGateway } from '../plans/plan-gateway';
import {
  PRIVATE_PLAN_CREATE_GATEWAY,
  PrivatePlanCreateGateway
} from '../private-plan-create/private-plan-create-gateway';
import { EnsurePlanForFarmInputDto } from './ensure-plan-for-farm.dtos';
import { EnsurePlanForFarmInputPort } from './ensure-plan-for-farm.input-port';
import {
  ENSURE_PLAN_FOR_FARM_OUTPUT_PORT,
  EnsurePlanForFarmOutputPort
} from './ensure-plan-for-farm.output-port';

const PLAN_ALREADY_EXISTS_KEY = 'plans.errors.plan_already_exists_annual';

@Injectable()
export class EnsurePlanForFarmUseCase implements EnsurePlanForFarmInputPort {
  constructor(
    @Inject(ENSURE_PLAN_FOR_FARM_OUTPUT_PORT) private readonly outputPort: EnsurePlanForFarmOutputPort,
    @Inject(PRIVATE_PLAN_CREATE_GATEWAY) private readonly planCreateGateway: PrivatePlanCreateGateway,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway
  ) {}

  execute(dto: EnsurePlanForFarmInputDto): void {
    if (dto.existingPlanId != null) {
      this.outputPort.onSuccess({ planId: dto.existingPlanId, created: false });
      return;
    }

    this.planCreateGateway.createPlan({ farmId: dto.farmId }).subscribe({
      next: (response) => this.outputPort.onSuccess({ planId: response.id, created: true }),
      error: (err: unknown) => this.handleCreateError(err, dto.farmId)
    });
  }

  private handleCreateError(err: unknown, farmId: number): void {
    if (this.isPlanAlreadyExistsError(err)) {
      this.planGateway
        .listPlans()
        .pipe(
          switchMap((plans) => {
            const existing = plans.find((plan) => plan.farm_id === farmId);
            if (existing) {
              return of(existing.id);
            }
            return throwError(() => new Error('plans.errors.not_found'));
          }),
          catchError((lookupErr: unknown) => {
            this.outputPort.onError({ message: this.resolveErrorMessage(lookupErr) });
            return of(null);
          })
        )
        .subscribe((planId) => {
          if (planId != null) {
            this.outputPort.onSuccess({ planId, created: false });
          }
        });
      return;
    }

    this.outputPort.onError({ message: this.resolveErrorMessage(err) });
  }

  private isPlanAlreadyExistsError(err: unknown): boolean {
    if (!(err instanceof HttpErrorResponse) || err.status !== 422) {
      return false;
    }
    const body = err.error as { error?: string } | undefined;
    return body?.error === PLAN_ALREADY_EXISTS_KEY;
  }

  private resolveErrorMessage(err: unknown): string {
    if (err instanceof HttpErrorResponse) {
      const serverKey = (err.error as { error?: string } | undefined)?.error?.trim();
      if (serverKey) {
        return serverKey;
      }
      return apiErrorI18nKey(err);
    }
    if (err instanceof Error) {
      return err.message;
    }
    return 'common.api_error.generic';
  }
}
