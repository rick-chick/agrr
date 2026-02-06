import { vi } from 'vitest';
import { ResetPublicPlanCreationStateUseCase } from './reset-public-plan-creation-state.usecase';
import { ResetPublicPlanCreationStateOutputPort } from './reset-public-plan-creation-state.output-port';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { ResetPublicPlanCreationStateInputDto } from './reset-public-plan-creation-state.dtos';

describe('ResetPublicPlanCreationStateUseCase', () => {
  it('calls PublicPlanStore.reset() when executed', () => {
    const resetSpy = vi.fn();
    const publicPlanStore = {
      reset: resetSpy,
      state: { farm: null, farmSize: null, selectedCrops: [], planId: null },
      state$: {} as any,
      setFarm: vi.fn(),
      setFarmSize: vi.fn(),
      setSelectedCrops: vi.fn(),
      setPlanId: vi.fn()
    } as unknown as PublicPlanStore;

    const outputPort: ResetPublicPlanCreationStateOutputPort = {};

    const useCase = new ResetPublicPlanCreationStateUseCase(outputPort, publicPlanStore);
    const inputDto: ResetPublicPlanCreationStateInputDto = {};

    useCase.execute(inputDto);

    expect(resetSpy).toHaveBeenCalledTimes(1);
  });
});
