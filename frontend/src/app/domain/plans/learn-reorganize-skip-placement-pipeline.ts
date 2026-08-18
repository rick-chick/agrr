import type { CultivationData } from './cultivation-plan-data';
import { buildGanttAdjustMove } from './gantt-chart-layout';
import {
  hasActiveLearnMasterUpdateFlow,
  hasLearnReorganizePipelineFailure,
  readLearnOrchestrationPipelineActive
} from './learn-master-update-orchestration';

export function buildCurrentPlacementAdjustMoves(
  cultivations: ReadonlyArray<CultivationData>
): ReturnType<typeof buildGanttAdjustMove>[] {
  return cultivations.map((cultivation) =>
    buildGanttAdjustMove(cultivation.id, cultivation.field_id, new Date(cultivation.start_date))
  );
}

export function shouldShowLearnOneClickReoptimizeCta(planId: number): boolean {
  return (
    hasActiveLearnMasterUpdateFlow(planId) &&
    !readLearnOrchestrationPipelineActive(planId) &&
    !hasLearnReorganizePipelineFailure(planId)
  );
}

export function buildLearnReorganizeSkipPlacementOptimizingNavigation(planId: number): {
  commands: (string | number)[];
} {
  return { commands: ['/plans', planId, 'optimizing'] };
}
