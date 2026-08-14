import {
  buildPlanTaskScheduleOrchestrationNavigation,
  type LearnOrchestrationStepKey
} from './learn-master-update-orchestration';

const AUTO_CHAIN_STORAGE_KEY = 'agrr:learn-orchestration-auto-chain';

function readAutoChainPlanIds(): Set<number> {
  const raw = sessionStorage.getItem(AUTO_CHAIN_STORAGE_KEY);
  if (!raw) {
    return new Set();
  }
  try {
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) {
      return new Set();
    }
    return new Set(parsed.filter((value): value is number => typeof value === 'number'));
  } catch {
    return new Set();
  }
}

function writeAutoChainPlanIds(planIds: Set<number>): void {
  sessionStorage.setItem(AUTO_CHAIN_STORAGE_KEY, JSON.stringify([...planIds]));
}

export function enableLearnOrchestrationAutoChain(planId: number): void {
  const planIds = readAutoChainPlanIds();
  planIds.add(planId);
  writeAutoChainPlanIds(planIds);
}

export function isLearnOrchestrationAutoChainEnabled(planId: number): boolean {
  return readAutoChainPlanIds().has(planId);
}

export function clearLearnOrchestrationAutoChain(planId?: number): void {
  if (planId == null) {
    sessionStorage.removeItem(AUTO_CHAIN_STORAGE_KEY);
    return;
  }
  const planIds = readAutoChainPlanIds();
  planIds.delete(planId);
  writeAutoChainPlanIds(planIds);
}

interface LearnOrchestrationAutoChainNavigation {
  commands: (string | number)[];
  queryParams: Record<string, string>;
}

export function resolveLearnOrchestrationAutoChainNavigationAfterStep(
  planId: number,
  completedStep: LearnOrchestrationStepKey
): LearnOrchestrationAutoChainNavigation | null {
  if (!isLearnOrchestrationAutoChainEnabled(planId)) {
    return null;
  }

  if (completedStep === 'placement') {
    return buildPlanTaskScheduleOrchestrationNavigation(planId, 'regenerate');
  }
  if (completedStep === 'regenerate') {
    return buildPlanTaskScheduleOrchestrationNavigation(planId, 'sync_verify');
  }
  if (completedStep === 'sync_verify') {
    clearLearnOrchestrationAutoChain(planId);
    return { commands: ['/plans', planId, 'learn'], queryParams: {} };
  }

  return null;
}
