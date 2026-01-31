import { Inject, Injectable } from '@angular/core';
import { CreatePublicPlanInputDto } from './create-public-plan.dtos';
import { CreatePublicPlanInputPort } from './create-public-plan.input-port';
import {
  CreatePublicPlanOutputPort,
  CREATE_PUBLIC_PLAN_OUTPUT_PORT
} from './create-public-plan.output-port';
import { PUBLIC_PLAN_GATEWAY, PublicPlanGateway } from './public-plan-gateway';

@Injectable()
export class CreatePublicPlanUseCase implements CreatePublicPlanInputPort {
  constructor(
    @Inject(CREATE_PUBLIC_PLAN_OUTPUT_PORT)
    private readonly outputPort: CreatePublicPlanOutputPort,
    @Inject(PUBLIC_PLAN_GATEWAY) private readonly publicPlanGateway: PublicPlanGateway
  ) {}

  execute(dto: CreatePublicPlanInputDto): void {
    this.publicPlanGateway
      .createPlan(dto.farmId, dto.farmSizeId, dto.cropIds)
      .subscribe({
        next: (response) => {
          this.outputPort.onSuccess(response);
          dto.onSuccess?.(response);
        },
        error: (err: Error & { error?: { error?: string; errors?: string[] } }) =>
          this.outputPort.onError({
            message:
              err.error?.errors?.join(', ') ??
              err.error?.error ??
              err?.message ??
              'Unknown error'
          })
      });
  }
}
