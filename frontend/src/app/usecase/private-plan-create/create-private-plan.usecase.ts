import { HttpErrorResponse } from '@angular/common/http';
import { Inject, Injectable } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { CreatePrivatePlanInputPort } from './create-private-plan.input-port';
import { CreatePrivatePlanOutputPort, CREATE_PRIVATE_PLAN_OUTPUT_PORT } from './create-private-plan.output-port';
import { PRIVATE_PLAN_CREATE_GATEWAY, PrivatePlanCreateGateway } from './private-plan-create-gateway';
import { CreatePrivatePlanInputDto } from './create-private-plan.dtos';

type ApiErrorBody = {
  error?: string;
  errors?: string[];
};

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
      error: (err: Error & { error?: ApiErrorBody }) =>
        this.outputPort.onError({ message: this.resolveErrorMessage(err) })
    });
  }

  private resolveErrorMessage(err: Error & { error?: ApiErrorBody }): string {
    const serverKey = err.error?.error?.trim();
    if (serverKey) {
      const translated = this.translate.instant(serverKey);
      return translated !== serverKey ? translated : serverKey;
    }
    const joined = err.error?.errors?.join(', ').trim();
    if (joined) {
      return joined;
    }
    if (err instanceof HttpErrorResponse) {
      return this.translate.instant(apiErrorI18nKey(err));
    }
    return err.message || this.translate.instant('common.api_error.generic');
  }
}