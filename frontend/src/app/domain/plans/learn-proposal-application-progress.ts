export type LearnProposalApplicationStatus =
  | 'not_started'
  | 'applied_pending_confirmation'
  | 'confirmed'
  | 'done'
  | 'dismissed';

export type LearnProposalKind = 'stage_gdd' | 'bp_timing';

export interface LearnPostMasterPayload {
  kind: LearnProposalKind;
  cropId: number;
  cropName: string;
  stageId?: number;
  stageName?: string;
  category?: string;
  appliedRequiredGdd?: number | null;
}

export function learnProposalApplicationProgressStorageKey(planId: number): string {
  return `agrr:learn-proposal-application-progress:${planId}`;
}

export function learnPostMasterPayloadStorageKey(planId: number): string {
  return `agrr:learn-post-master:${planId}`;
}

export function learnBpTimingApplyContextStorageKey(cropId: number): string {
  return `agrr:learn-bp-timing-apply-context:${cropId}`;
}

export interface LearnBpTimingApplyContext {
  planId: number;
  cropId: number;
  cropName: string;
  category: string;
}

export function stageGddProposalProgressKey(cropId: number, stageId: number): string {
  return `stage_gdd:${cropId}:${stageId}`;
}

export function bpTimingProposalProgressKey(cropId: number, category: string): string {
  return `bp_timing:${cropId}:${category}`;
}

type ProgressMap = Record<string, LearnProposalApplicationStatus>;

const progressCache: Record<number, ProgressMap> = {};

type ProgressPatchHandler = (
  planId: number,
  updates: Record<string, LearnProposalApplicationStatus>
) => void;

let patchHandler: ProgressPatchHandler | null = null;

export function registerLearnProposalApplicationProgressPatchHandler(
  handler: ProgressPatchHandler
): void {
  patchHandler = handler;
}

export function clearLearnProposalApplicationProgressCache(planId?: number): void {
  if (planId == null) {
    for (const key of Object.keys(progressCache)) {
      delete progressCache[Number(key)];
    }
    return;
  }
  delete progressCache[planId];
}

export function hydrateLearnProposalApplicationProgress(
  planId: number,
  map: Record<string, LearnProposalApplicationStatus>
): void {
  progressCache[planId] = { ...map };
}

function readProgressMap(planId: number): ProgressMap {
  return progressCache[planId] ?? {};
}

function writeProgressMap(planId: number, map: ProgressMap): void {
  progressCache[planId] = map;
}

function syncProgressUpdates(
  planId: number,
  updates: Record<string, LearnProposalApplicationStatus>
): void {
  if (patchHandler && Object.keys(updates).length > 0) {
    patchHandler(planId, updates);
  }
}

export function readLearnProposalApplicationProgress(planId: number): ProgressMap {
  return { ...readProgressMap(planId) };
}

export function resolveLearnProposalApplicationStatus(
  planId: number,
  proposalKey: string
): LearnProposalApplicationStatus {
  return readProgressMap(planId)[proposalKey] ?? 'not_started';
}

function markProposalAppliedPending(planId: number, proposalKey: string): void {
  const map = readProgressMap(planId);
  map[proposalKey] = 'applied_pending_confirmation';
  writeProgressMap(planId, map);
  syncProgressUpdates(planId, { [proposalKey]: 'applied_pending_confirmation' });
}

export function markStageGddProposalAppliedPending(
  planId: number,
  input: { cropId: number; stageId: number }
): void {
  markProposalAppliedPending(planId, stageGddProposalProgressKey(input.cropId, input.stageId));
}

export function markBpTimingProposalAppliedPending(
  planId: number,
  input: { cropId: number; category: string }
): void {
  markProposalAppliedPending(planId, bpTimingProposalProgressKey(input.cropId, input.category));
}

export function markStageGddProposalDismissed(
  planId: number,
  input: { cropId: number; stageId: number }
): void {
  dismissProposalIfNotStarted(planId, stageGddProposalProgressKey(input.cropId, input.stageId));
}

export function markBpTimingProposalDismissed(
  planId: number,
  input: { cropId: number; category: string }
): void {
  dismissProposalIfNotStarted(planId, bpTimingProposalProgressKey(input.cropId, input.category));
}

function dismissProposalIfNotStarted(planId: number, proposalKey: string): void {
  const current = resolveLearnProposalApplicationStatus(planId, proposalKey);
  if (current === 'not_started') {
    setProposalStatus(planId, proposalKey, 'dismissed');
  }
}

export function proposalKeyFromPostMasterPayload(payload: LearnPostMasterPayload): string {
  if (payload.kind === 'stage_gdd') {
    if (payload.stageId == null) {
      throw new Error('stageId is required for stage_gdd post_master payload');
    }
    return stageGddProposalProgressKey(payload.cropId, payload.stageId);
  }
  if (!payload.category) {
    throw new Error('category is required for bp_timing post_master payload');
  }
  return bpTimingProposalProgressKey(payload.cropId, payload.category);
}

function setProposalStatus(
  planId: number,
  proposalKey: string,
  status: LearnProposalApplicationStatus
): void {
  const map = readProgressMap(planId);
  map[proposalKey] = status;
  writeProgressMap(planId, map);
  syncProgressUpdates(planId, { [proposalKey]: status });
}

export function markLearnProposalConfirmed(planId: number, proposalKey: string): void {
  setProposalStatus(planId, proposalKey, 'confirmed');
}

export function markLearnProposalDismissed(planId: number, proposalKey: string): void {
  dismissProposalIfNotStarted(planId, proposalKey);
}

export function isLearnProposalResolved(status: LearnProposalApplicationStatus): boolean {
  return status === 'done' || status === 'dismissed';
}

export function confirmLearnProposalFromPostMaster(
  planId: number,
  payload: LearnPostMasterPayload
): void {
  const proposalKey = proposalKeyFromPostMasterPayload(payload);
  const current = resolveLearnProposalApplicationStatus(planId, proposalKey);
  if (current === 'applied_pending_confirmation') {
    markLearnProposalConfirmed(planId, proposalKey);
  }
}

export function markAllConfirmedProposalsDone(planId: number): void {
  const map = readProgressMap(planId);
  const updates: Record<string, LearnProposalApplicationStatus> = {};
  let changed = false;
  for (const [key, status] of Object.entries(map)) {
    if (status === 'confirmed') {
      map[key] = 'done';
      updates[key] = 'done';
      changed = true;
    }
  }
  if (changed) {
    writeProgressMap(planId, map);
    syncProgressUpdates(planId, updates);
  }
}

export function storeLearnPostMasterPayload(planId: number, payload: LearnPostMasterPayload): void {
  sessionStorage.setItem(learnPostMasterPayloadStorageKey(planId), JSON.stringify(payload));
}

export function readLearnPostMasterPayload(planId: number): LearnPostMasterPayload | null {
  const raw = sessionStorage.getItem(learnPostMasterPayloadStorageKey(planId));
  if (!raw) {
    return null;
  }
  try {
    const parsed: unknown = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') {
      return null;
    }
    return parsed as LearnPostMasterPayload;
  } catch {
    return null;
  }
}

export function clearLearnPostMasterPayload(planId: number): void {
  sessionStorage.removeItem(learnPostMasterPayloadStorageKey(planId));
}

export function storeLearnBpTimingApplyContext(
  cropId: number,
  context: LearnBpTimingApplyContext
): void {
  sessionStorage.setItem(
    learnBpTimingApplyContextStorageKey(cropId),
    JSON.stringify(context)
  );
}

export function readLearnBpTimingApplyContext(cropId: number): LearnBpTimingApplyContext | null {
  const raw = sessionStorage.getItem(learnBpTimingApplyContextStorageKey(cropId));
  if (!raw) {
    return null;
  }
  try {
    const parsed: unknown = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') {
      return null;
    }
    return parsed as LearnBpTimingApplyContext;
  } catch {
    return null;
  }
}

export function clearLearnBpTimingApplyContext(cropId: number): void {
  sessionStorage.removeItem(learnBpTimingApplyContextStorageKey(cropId));
}

export function buildLearnPostMasterNavigation(planId: number): {
  commands: (string | number)[];
  queryParams: { followUp: 'post_master' };
} {
  return {
    commands: ['/plans', planId, 'learn'],
    queryParams: { followUp: 'post_master' }
  };
}

export function parsePlanLearnFollowUp(raw: string | null | undefined): 'post_master' | null {
  return raw === 'post_master' ? 'post_master' : null;
}
