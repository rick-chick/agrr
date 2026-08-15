import type { WorkHubFarmRow } from './work-hub-farm-row';

export function sortWorkHubFarmsByActionRequired(farms: WorkHubFarmRow[]): WorkHubFarmRow[] {
  return [...farms].sort((left, right) => {
    const actionDiff = right.thresholdExceededCount - left.thresholdExceededCount;
    if (actionDiff !== 0) {
      return actionDiff;
    }
    return left.farmId - right.farmId;
  });
}
