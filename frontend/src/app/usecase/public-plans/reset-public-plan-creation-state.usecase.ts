import { Inject, Injectable } from '@angular/core';
import { ResetPublicPlanCreationStateInputDto } from './reset-public-plan-creation-state.dtos';
import { ResetPublicPlanCreationStateInputPort } from './reset-public-plan-creation-state.input-port';
import {
  ResetPublicPlanCreationStateOutputPort,
  RESET_PUBLIC_PLAN_CREATION_STATE_OUTPUT_PORT
} from './reset-public-plan-creation-state.output-port';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';

@Injectable()
export class ResetPublicPlanCreationStateUseCase implements ResetPublicPlanCreationStateInputPort {
  constructor(
    @Inject(RESET_PUBLIC_PLAN_CREATION_STATE_OUTPUT_PORT)
    private readonly outputPort: ResetPublicPlanCreationStateOutputPort,
    private readonly publicPlanStore: PublicPlanStore
  ) {}

  execute(dto: ResetPublicPlanCreationStateInputDto): void {
    // Reset the store state including planId and clear session storage
    this.publicPlanStore.reset();
    console.log('🔄 [ResetPublicPlanCreationStateUseCase] PublicPlanStore state reset');
  }
}
