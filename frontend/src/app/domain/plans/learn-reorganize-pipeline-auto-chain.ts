import { buildPlanDetailAdjustNavigation } from './learn-master-update-orchestration';

const autoChainCache: Record<number, boolean> = {};

export function storeLearnReorganizePipelineAutoChain(planId: number): void {
  autoChainCache[planId] = true;
}

export function readLearnReorganizePipelineAutoChain(planId: number): boolean {
  return autoChainCache[planId] ?? false;
}

export function clearLearnReorganizePipelineAutoChain(planId?: number): void {
  if (planId == null) {
    for (const key of Object.keys(autoChainCache)) {
      delete autoChainCache[Number(key)];
    }
    return;
  }
  delete autoChainCache[planId];
}

export function buildLearnReorganizePipelineStartNavigation(planId: number): {
  commands: (string | number)[];
  queryParams: { learningOrchestration: 'adjust' };
} {
  return buildPlanDetailAdjustNavigation(planId);
}

export function buildLearnReorganizePipelineRegenerateNavigation(planId: number): {
  commands: (string | number)[];
  queryParams: { learningOrchestration: 'regenerate' };
} {
  return {
    commands: ['/plans', planId, 'task_schedule'],
    queryParams: { learningOrchestration: 'regenerate' }
  };
}

export function buildLearnReorganizePipelineSyncVerifyNavigation(planId: number): {
  commands: (string | number)[];
  queryParams: { learningOrchestration: 'sync_verify' };
} {
  return {
    commands: ['/plans', planId, 'task_schedule'],
    queryParams: { learningOrchestration: 'sync_verify' }
  };
}
