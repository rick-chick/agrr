import { Inject, Injectable } from '@angular/core';
import { CreatePublicPlanInputDto } from './create-public-plan.dtos';
import { CreatePublicPlanInputPort } from './create-public-plan.input-port';
import {
  CreatePublicPlanOutputPort,
  CREATE_PUBLIC_PLAN_OUTPUT_PORT
} from './create-public-plan.output-port';
import { PUBLIC_PLAN_GATEWAY, PublicPlanGateway } from './public-plan-gateway';
import {
  PUBLIC_PLAN_SESSION_PORT,
  PublicPlanSessionPort
} from './public-plan-session.port';

@Injectable()
export class CreatePublicPlanUseCase implements CreatePublicPlanInputPort {
  constructor(
    @Inject(CREATE_PUBLIC_PLAN_OUTPUT_PORT)
    private readonly outputPort: CreatePublicPlanOutputPort,
    @Inject(PUBLIC_PLAN_GATEWAY) private readonly publicPlanGateway: PublicPlanGateway,
    @Inject(PUBLIC_PLAN_SESSION_PORT) private readonly publicPlanSession: PublicPlanSessionPort
  ) {}

  execute(dto: CreatePublicPlanInputDto): void {
    this.publicPlanGateway
      .createPlan(dto.farmId, dto.farmSizeId, dto.cropIds)
      .subscribe({
        next: (response) => {
          // Update store with the new planId before calling onSuccess
          // This ensures the store is updated before navigation
          this.publicPlanSession.setPlanId(response.plan_id);
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
