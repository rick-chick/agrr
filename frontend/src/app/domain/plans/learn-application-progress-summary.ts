import type { LearnProposalApplicationStatus } from './learn-proposal-application-progress';

export function countAddressedLearnApplicationProgress(
  statuses: ReadonlyArray<LearnProposalApplicationStatus>
): { addressed: number; total: number } {
  return {
    addressed: statuses.filter((status) => status !== 'not_started').length,
    total: statuses.length
  };
}
