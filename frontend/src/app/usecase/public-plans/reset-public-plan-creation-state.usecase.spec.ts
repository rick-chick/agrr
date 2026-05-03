import { vi } from 'vitest';
import { ResetPublicPlanCreationStateUseCase } from './reset-public-plan-creation-state.usecase';
import { ResetPublicPlanCreationStateOutputPort } from './reset-public-plan-creation-state.output-port';
import { PublicPlanSessionPort } from './public-plan-session.port';
import { ResetPublicPlanCreationStateInputDto } from './reset-public-plan-creation-state.dtos';

describe('ResetPublicPlanCreationStateUseCase', () => {
  it('calls session reset when executed', () => {
    const resetSpy = vi.fn();
    const publicPlanSession: PublicPlanSessionPort = {
      reset: resetSpy,
      setPlanId: vi.fn()
    };

    const outputPort: ResetPublicPlanCreationStateOutputPort = {};

    const useCase = new ResetPublicPlanCreationStateUseCase(outputPort, publicPlanSession);
    const inputDto: ResetPublicPlanCreationStateInputDto = {};

    useCase.execute(inputDto);

    expect(resetSpy).toHaveBeenCalledTimes(1);
  });
});
