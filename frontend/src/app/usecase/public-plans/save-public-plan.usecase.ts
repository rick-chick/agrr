import { Inject, Injectable } from '@angular/core';
import { SavePublicPlanInputPort } from './save-public-plan.input-port';
import { SavePublicPlanOutputPort, SAVE_PUBLIC_PLAN_OUTPUT_PORT } from './save-public-plan.output-port';
import { PUBLIC_PLAN_GATEWAY, PublicPlanGateway } from './public-plan-gateway';
import { SavePublicPlanInputDto } from './save-public-plan.dtos';

@Injectable()
export class SavePublicPlanUseCase implements SavePublicPlanInputPort {
  constructor(
    @Inject(SAVE_PUBLIC_PLAN_OUTPUT_PORT) private readonly outputPort: SavePublicPlanOutputPort,
    @Inject(PUBLIC_PLAN_GATEWAY) private readonly publicPlanGateway: PublicPlanGateway
  ) {}

  execute(dto: SavePublicPlanInputDto): void {
    this.publicPlanGateway.savePlan(dto.planId).subscribe({
      next: (response) => {
        if (response.success) {
          this.outputPort.present({ message: 'Plan saved successfully' });
        } else {
          this.outputPort.onError({ message: response.error || 'Failed to save plan' });
        }
      },
      error: (err) => this.outputPort.onError({ message: err.message || 'Failed to save plan' })
    });
  }
}