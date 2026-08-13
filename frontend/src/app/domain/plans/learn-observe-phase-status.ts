export const PLAN_LEARN_VARIANCE_SECTION_ID = 'plan-learn-loop-proposals';

export interface LearnObservePhaseStatusInput {
  unrecordedCount: number;
  varianceLoaded: boolean;
}

export function shouldShowLearnUnrecordedCta(input: LearnObservePhaseStatusInput): boolean {
  return input.varianceLoaded && input.unrecordedCount > 0;
}

export function isLearnObservePhaseComplete(input: LearnObservePhaseStatusInput): boolean {
  return input.varianceLoaded && input.unrecordedCount === 0;
}
