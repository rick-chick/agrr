import { Inject, Injectable } from '@angular/core';
import { ResetPublicPlanCreationStateInputDto } from './reset-public-plan-creation-state.dtos';
import { ResetPublicPlanCreationStateInputPort } from './reset-public-plan-creation-state.input-port';
import {
  ResetPublicPlanCreationStateOutputPort,
  RESET_PUBLIC_PLAN_CREATION_STATE_OUTPUT_PORT
} from './reset-public-plan-creation-state.output-port';
import {
  PUBLIC_PLAN_SESSION_PORT,
  PublicPlanSessionPort
} from './public-plan-session.port';

@Injectable()
export class ResetPublicPlanCreationStateUseCase implements ResetPublicPlanCreationStateInputPort {
  constructor(
    @Inject(RESET_PUBLIC_PLAN_CREATION_STATE_OUTPUT_PORT)
    private readonly outputPort: ResetPublicPlanCreationStateOutputPort,
    @Inject(PUBLIC_PLAN_SESSION_PORT) private readonly publicPlanSession: PublicPlanSessionPort
  ) {}

  execute(_dto: ResetPublicPlanCreationStateInputDto): void {
    this.publicPlanSession.reset();
  }
}
