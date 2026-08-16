const STORAGE_KEY_PREFIX = 'agrr.weatherReschedule.dismissed';

function storageKey(planId: number): string {
  return `${STORAGE_KEY_PREFIX}.${planId}`;
}

export function readDismissedWeatherRescheduleProposalIds(planId: number): Set<string> {
  if (typeof sessionStorage === 'undefined') {
    return new Set();
  }
  const raw = sessionStorage.getItem(storageKey(planId));
  if (!raw) {
    return new Set();
  }
  try {
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) {
      return new Set();
    }
    return new Set(parsed.filter((id): id is string => typeof id === 'string'));
  } catch {
    return new Set();
  }
}

export function dismissWeatherRescheduleProposal(planId: number, proposalId: string): void {
  if (typeof sessionStorage === 'undefined') {
    return;
  }
  const dismissed = readDismissedWeatherRescheduleProposalIds(planId);
  dismissed.add(proposalId);
  sessionStorage.setItem(storageKey(planId), JSON.stringify([...dismissed]));
}

export function filterActiveWeatherRescheduleProposals<T extends { id: string }>(
  planId: number,
  proposals: T[]
): T[] {
  const dismissed = readDismissedWeatherRescheduleProposalIds(planId);
  return proposals.filter((proposal) => !dismissed.has(proposal.id));
}
