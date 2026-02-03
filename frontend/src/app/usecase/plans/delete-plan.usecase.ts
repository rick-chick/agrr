import { Inject, Injectable } from '@angular/core';
import { DeletePlanInputPort } from './delete-plan.input-port';
import { DeletePlanSuccessDto, DeletePlanInputDto } from './delete-plan.dtos';
import {
  DeletePlanOutputPort,
  DELETE_PLAN_OUTPUT_PORT
} from './delete-plan.output-port';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';

@Injectable()
export class DeletePlanUseCase implements DeletePlanInputPort {
  constructor(
    @Inject(DELETE_PLAN_OUTPUT_PORT) private readonly outputPort: DeletePlanOutputPort,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway
  ) {}

  execute(dto: DeletePlanInputDto): void {
    this.planGateway.deletePlan(dto.planId).subscribe({
      next: (undo) => {
        this.outputPort.onSuccess({
          deletedPlanId: dto.planId,
          undo,
          refresh: dto.onAfterUndo
        });
        dto.onSuccess?.();
      },
      error: (err: Error & { error?: { error?: string; errors?: string[] } }) =>
        this.outputPort.onError({
          message:
            err?.error?.error ??
            err?.error?.errors?.join(', ') ??
            err?.message ??
            'Unknown error',
          scope: 'delete-plan'
        })
    });
  }
}
