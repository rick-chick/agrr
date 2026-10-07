import { HttpErrorResponse } from '@angular/common/http';
import { Inject, Injectable } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { apiErrorMessages } from '../../core/api-error-message';
import { CreatePrivatePlanInputPort } from './create-private-plan.input-port';
import { CreatePrivatePlanOutputPort, CREATE_PRIVATE_PLAN_OUTPUT_PORT } from './create-private-plan.output-port';
import { PRIVATE_PLAN_CREATE_GATEWAY, PrivatePlanCreateGateway } from './private-plan-create-gateway';
import { CreatePrivatePlanInputDto } from './create-private-plan.dtos';

@Injectable()
export class CreatePrivatePlanUseCase implements CreatePrivatePlanInputPort {
  constructor(
    @Inject(CREATE_PRIVATE_PLAN_OUTPUT_PORT) private readonly outputPort: CreatePrivatePlanOutputPort,
    @Inject(PRIVATE_PLAN_CREATE_GATEWAY) private readonly gateway: PrivatePlanCreateGateway,
    private readonly translate: TranslateService
  ) {}

  execute(dto: CreatePrivatePlanInputDto): void {
    this.gateway.createPlan(dto).subscribe({
      next: (response) => this.outputPort.present(response),
      error: (err: unknown) =>
        this.outputPort.onError({ message: this.resolveErrorMessage(err) })
    });
  }

  private resolveErrorMessage(err: unknown): string {
    if (err instanceof HttpErrorResponse) {
      const keys = apiErrorMessages(err);
      if (keys.length > 0) {
        return keys
          .map((key) => {
            const translated = this.translate.instant(key);
            return translated !== key ? translated : key;
          })
          .join(', ');
      }
      return this.translate.instant(apiErrorI18nKey(err));
    }
    if (err instanceof Error) {
      return err.message || this.translate.instant('common.api_error.generic');
    }
    return this.translate.instant('common.api_error.generic');
  }
}