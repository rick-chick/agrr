import { HttpErrorResponse } from '@angular/common/http';
import { Inject, Injectable } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { apiErrorMessagesFromBody } from '../../core/api-error-body';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { apiErrorMessages } from '../../core/api-error-message';
import { SavePublicPlanInputPort } from './save-public-plan.input-port';
import { SavePublicPlanOutputPort, SAVE_PUBLIC_PLAN_OUTPUT_PORT } from './save-public-plan.output-port';
import { PUBLIC_PLAN_GATEWAY, PublicPlanGateway } from './public-plan-gateway';
import { SavePublicPlanInputDto } from './save-public-plan.dtos';
import { SavePublicPlanResponse } from './public-plan-gateway';

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
          message: this.translateResponseErrorKeys(response)
        });
      },
      error: (err: unknown) =>
        this.outputPort.onError({
          message: this.resolveHttpErrorMessage(err)
        })
    });
  }

  private translateResponseErrorKeys(response: SavePublicPlanResponse): string {
    const keys = apiErrorMessagesFromBody(response);
    if (keys.length > 0) {
      return this.translateErrorKeys(keys);
    }
    return this.translate.instant('public_plans.save.error');
  }

  private resolveHttpErrorMessage(err: unknown): string {
    if (err instanceof HttpErrorResponse) {
      const keys = apiErrorMessages(err);
      if (keys.length > 0) {
        return this.translateErrorKeys(keys);
      }
      return this.translate.instant(apiErrorI18nKey(err));
    }
    if (err instanceof Error && err.message.trim().length > 0) {
      return err.message;
    }
    return this.translate.instant('public_plans.save.error');
  }

  private translateErrorKeys(keys: string[]): string {
    return keys
      .map((key) => {
        const translated = this.translate.instant(key);
        return translated !== key ? translated : key;
      })
      .join(', ');
  }
}