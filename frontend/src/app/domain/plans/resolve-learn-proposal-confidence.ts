export type LearnProposalConfidence = 'high' | 'medium' | 'low';

export function resolveLearnProposalConfidence(input: {
  unrecordedCount: number;
  actionRequiredCount: number;
}): LearnProposalConfidence {
  if (input.unrecordedCount > 0) return 'low';
  if (input.actionRequiredCount > 0) return 'medium';
  return 'high';
}
