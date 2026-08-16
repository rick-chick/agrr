import { firstValueFrom, of } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import { HydrateReorganizeOrchestrationUseCase } from './hydrate-reorganize-orchestration.usecase';
import { LoadPlanLearnCarryoverUseCase } from './load-plan-learn-carryover.usecase';

describe('HydrateReorganizeOrchestrationUseCase', () => {
  it('delegates to loadLearningSnapshot', async () => {
    const snapshot = {
      plan_id: 9,
      source_plan_id: 0,
      reorganize_orchestration_progress: { pipeline_active: true, current_phase: 'placement' },
      summary: { plan_id: 9, unrecorded_count: 0, categories: [], top_variance_items: [] }
    };
    const carryoverUseCase = {
      loadLearningSnapshot: vi.fn(() => of(snapshot))
    } as unknown as LoadPlanLearnCarryoverUseCase;

    const useCase = new HydrateReorganizeOrchestrationUseCase(carryoverUseCase);
    await expect(firstValueFrom(useCase.execute(9))).resolves.toEqual(snapshot);
    expect(carryoverUseCase.loadLearningSnapshot).toHaveBeenCalledWith(9);
  });
});
