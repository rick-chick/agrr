import { HttpErrorResponse } from '@angular/common/http';
import { Inject, Injectable } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { SavePublicPlanInputPort } from './save-public-plan.input-port';
import { SavePublicPlanOutputPort, SAVE_PUBLIC_PLAN_OUTPUT_PORT } from './save-public-plan.output-port';
import { PUBLIC_PLAN_GATEWAY, PublicPlanGateway } from './public-plan-gateway';
import { SavePublicPlanInputDto } from './save-public-plan.dtos';

type ApiErrorBody = {
  error?: string;
  errors?: string[];
};

@Injectable()
export class SavePublicPlanUseCase implements SavePublicPlanInputPort {
  constructor(
    @Inject(SAVE_PUBLIC_PLAN_OUTPUT_PORT) private readonly outputPort: SavePublicPlanOutputPort,
    @Inject(PUBLIC_PLAN_GATEWAY) private readonly publicPlanGateway: PublicPlanGateway,
    private readonly translate: TranslateService
  ) {}

  execute(dto: SavePublicPlanInputDto): void {
    this.publicPlanGateway.savePlan(dto.planId).subscribe({
      next: (response) => {
        if (response.success) {
          const message = response.plan_reused
            ? this.translate.instant('plans.errors.plan_already_exists_annual')
            : this.translate.instant('public_plans.save.success');
          this.outputPort.present({
            message,
            cultivation_plan_id: response.cultivation_plan_id,
            plan_reused: response.plan_reused === true
          });
          return;
        }
        this.outputPort.onError({
          message:
            response.error?.trim() ||
            this.translate.instant('public_plans.save.error')
        });
      },
      error: (err: Error & { error?: ApiErrorBody }) =>
        this.outputPort.onError({
          message: this.resolveErrorMessage(err)
        })
    });
  }

  private resolveErrorMessage(err: Error & { error?: ApiErrorBody }): string {
    const fromBody =
      err?.error?.error?.trim() ||
      err?.error?.errors?.filter((e) => e?.trim()).join(', ');
    if (fromBody) {
      return fromBody;
    }
    if (err instanceof HttpErrorResponse || (err as HttpErrorResponse).status !== undefined) {
      return this.translate.instant(apiErrorI18nKey(err));
    }
    if (err?.message?.trim()) {
      return err.message;
    }
    return this.translate.instant('public_plans.save.error');
  }
}
