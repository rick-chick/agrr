export type LearnObservePhaseStatus = 'unrecorded' | 'complete';

export function resolveLearnObservePhaseStatus(input: {
  varianceLoading: boolean;
  varianceError: string | null;
  unrecordedCount: number | null;
}): LearnObservePhaseStatus | null {
  if (input.varianceLoading || input.varianceError != null || input.unrecordedCount == null) {
    return null;
  }

  return input.unrecordedCount > 0 ? 'unrecorded' : 'complete';
}
