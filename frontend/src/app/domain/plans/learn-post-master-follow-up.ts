import type { LearnProposalKind } from './learn-proposal-application-progress';

export const LEARN_FOLLOW_UP_POST_MASTER = 'post_master';

export interface LearnPostMasterContext {
  kind: LearnProposalKind;
  cropName: string;
  detailLabel: string;
}

export function parseLearnFollowUp(raw: string | null | undefined): string | null {
  if (!raw || raw.trim() === '') {
    return null;
  }
  return raw;
}

export function isLearnPostMasterFollowUp(raw: string | null | undefined): boolean {
  return parseLearnFollowUp(raw) === LEARN_FOLLOW_UP_POST_MASTER;
}

export function learnPostMasterContextStorageKey(planId: number): string {
  return `agrr:learn-post-master-context:${planId}`;
}

export function readLearnPostMasterContext(
  planId: number,
  storage: Storage | null = sessionStorage
): LearnPostMasterContext | null {
  if (!storage) {
    return null;
  }
  const raw = storage.getItem(learnPostMasterContextStorageKey(planId));
  if (!raw) {
    return null;
  }
  try {
    const parsed: unknown = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') {
      return null;
    }
    const record = parsed as Record<string, unknown>;
    if (
      (record['kind'] !== 'stage_gdd' && record['kind'] !== 'bp_timing') ||
      typeof record['cropName'] !== 'string' ||
      typeof record['detailLabel'] !== 'string'
    ) {
      return null;
    }
    return {
      kind: record['kind'],
      cropName: record['cropName'],
      detailLabel: record['detailLabel']
    };
  } catch {
    return null;
  }
}

export function writeLearnPostMasterContext(
  planId: number,
  context: LearnPostMasterContext,
  storage: Storage | null = sessionStorage
): void {
  if (!storage) {
    return;
  }
  storage.setItem(learnPostMasterContextStorageKey(planId), JSON.stringify(context));
}

export function clearLearnPostMasterContext(
  planId: number,
  storage: Storage | null = sessionStorage
): void {
  storage?.removeItem(learnPostMasterContextStorageKey(planId));
}

export function learnPostMasterPath(planId: number): (string | number)[] {
  return ['/plans', planId, 'learn'];
}

export function learnPostMasterQueryParams(): Record<string, string> {
  return { followUp: LEARN_FOLLOW_UP_POST_MASTER };
}
