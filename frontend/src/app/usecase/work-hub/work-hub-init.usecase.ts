import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { WORK_HUB_GATEWAY, WorkHubGateway } from './work-hub-gateway';
import { EnsurePlanForFarmUseCase } from './ensure-plan-for-farm.usecase';
import { WorkHubInitInputPort } from './work-hub-init.input-port';
import { WORK_HUB_INIT_OUTPUT_PORT, WorkHubInitOutputPort } from './work-hub-init.output-port';

@Injectable()
export class WorkHubInitUseCase implements WorkHubInitInputPort {
  constructor(
    @Inject(WORK_HUB_INIT_OUTPUT_PORT) private readonly outputPort: WorkHubInitOutputPort,
    @Inject(WORK_HUB_GATEWAY) private readonly workHubGateway: WorkHubGateway,
    private readonly ensurePlanForFarmUseCase: EnsurePlanForFarmUseCase
  ) {}

  execute(): void {
    this.workHubGateway.listHubFarms().subscribe({
      next: (farms) => {
        if (farms.length === 1 && farms[0].hasValidFields) {
          this.outputPort.present({ farms });
          this.outputPort.beginEnsure();
          this.ensurePlanForFarmUseCase.execute({
            farmId: farms[0].farmId,
            existingPlanId: farms[0].planId
          });
          return;
        }
        this.outputPort.present({ farms });
      },
      error: (err: unknown) =>
        this.outputPort.onError({
          message: err instanceof Error ? err.message : apiErrorI18nKey(err as never)
        })
    });
  }
}
