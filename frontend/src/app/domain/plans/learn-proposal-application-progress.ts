import type { CropSetupProposalBody } from '../crops/crop-setup-proposal';
import type { LearnHandoffState } from './plan-variance-learning-snapshot';

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

/** @deprecated sessionStorage key — retained for test compatibility only */
export function learnPostMasterPayloadStorageKey(planId: number): string {
  return `agrr:learn-post-master:${planId}`;
}

/** @deprecated sessionStorage key — retained for test compatibility only */
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

interface LearnHandoffCache {
  postMasterPayload: LearnPostMasterPayload | null;
  bpTimingApplyContext: LearnBpTimingApplyContext | null;
  blueprintPrefillByCropId: Record<number, CropSetupProposalBody>;
}

const handoffCache: Record<number, LearnHandoffCache> = {};

export interface LearnHandoffPatch {
  post_master_payload?: LearnPostMasterPayload | null;
  bp_timing_apply_context?: LearnBpTimingApplyContext | null;
  blueprint_prefill?: {
    crop_id: number;
    body: CropSetupProposalBody | null;
  };
}

type HandoffPatchHandler = (planId: number, patch: LearnHandoffPatch) => void;

let handoffPatchHandler: HandoffPatchHandler | null = null;

function emptyHandoffCache(): LearnHandoffCache {
  return {
    postMasterPayload: null,
    bpTimingApplyContext: null,
    blueprintPrefillByCropId: {}
  };
}

function readHandoffCache(planId: number): LearnHandoffCache {
  return handoffCache[planId] ?? emptyHandoffCache();
}

function writeHandoffCache(planId: number, cache: LearnHandoffCache): void {
  handoffCache[planId] = cache;
}

function syncHandoffPatch(planId: number, patch: LearnHandoffPatch): void {
  if (handoffPatchHandler) {
    handoffPatchHandler(planId, patch);
  }
}

export function registerLearnHandoffPatchHandler(handler: HandoffPatchHandler): void {
  handoffPatchHandler = handler;
}

export function clearLearnHandoffCache(planId?: number): void {
  if (planId == null) {
    for (const key of Object.keys(handoffCache)) {
      delete handoffCache[Number(key)];
    }
    return;
  }
  delete handoffCache[planId];
}

export function hydrateLearnHandoff(planId: number, handoff: LearnHandoffState | undefined): void {
  if (!handoff) {
    writeHandoffCache(planId, emptyHandoffCache());
    return;
  }

  const blueprintPrefillByCropId: Record<number, CropSetupProposalBody> = {};
  for (const [cropId, body] of Object.entries(handoff.blueprint_prefill_by_crop_id ?? {})) {
    blueprintPrefillByCropId[Number(cropId)] = body as CropSetupProposalBody;
  }

  writeHandoffCache(planId, {
    postMasterPayload: (handoff.post_master_payload as LearnPostMasterPayload | null) ?? null,
    bpTimingApplyContext:
      (handoff.bp_timing_apply_context as LearnBpTimingApplyContext | null) ?? null,
    blueprintPrefillByCropId
  });
}

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
  const cache = readHandoffCache(planId);
  cache.postMasterPayload = payload;
  writeHandoffCache(planId, cache);
  syncHandoffPatch(planId, { post_master_payload: payload });
}

export function readLearnPostMasterPayload(planId: number): LearnPostMasterPayload | null {
  return readHandoffCache(planId).postMasterPayload;
}

export function clearLearnPostMasterPayload(planId: number): void {
  const cache = readHandoffCache(planId);
  cache.postMasterPayload = null;
  writeHandoffCache(planId, cache);
  syncHandoffPatch(planId, { post_master_payload: null });
}

export function storeLearnBpTimingApplyContext(
  planId: number,
  context: LearnBpTimingApplyContext
): void {
  const cache = readHandoffCache(planId);
  cache.bpTimingApplyContext = context;
  writeHandoffCache(planId, cache);
  syncHandoffPatch(planId, { bp_timing_apply_context: context });
}

export function readLearnBpTimingApplyContext(
  planId: number,
  cropId: number
): LearnBpTimingApplyContext | null {
  const context = readHandoffCache(planId).bpTimingApplyContext;
  if (!context || context.cropId !== cropId) {
    return null;
  }
  return context;
}

export function clearLearnBpTimingApplyContext(planId: number, cropId: number): void {
  const cache = readHandoffCache(planId);
  if (cache.bpTimingApplyContext?.cropId === cropId) {
    cache.bpTimingApplyContext = null;
    writeHandoffCache(planId, cache);
    syncHandoffPatch(planId, { bp_timing_apply_context: null });
  }
}

export function storeBlueprintTimingPrefill(
  planId: number,
  cropId: number,
  body: CropSetupProposalBody
): void {
  const cache = readHandoffCache(planId);
  cache.blueprintPrefillByCropId[cropId] = body;
  writeHandoffCache(planId, cache);
  syncHandoffPatch(planId, {
    blueprint_prefill: { crop_id: cropId, body }
  });
}

export function readBlueprintTimingPrefill(
  planId: number,
  cropId: number
): CropSetupProposalBody | null {
  return readHandoffCache(planId).blueprintPrefillByCropId[cropId] ?? null;
}

export function clearBlueprintTimingPrefill(planId: number, cropId: number): void {
  const cache = readHandoffCache(planId);
  if (cache.blueprintPrefillByCropId[cropId] == null) {
    return;
  }
  delete cache.blueprintPrefillByCropId[cropId];
  writeHandoffCache(planId, cache);
  syncHandoffPatch(planId, {
    blueprint_prefill: { crop_id: cropId, body: null }
  });
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
