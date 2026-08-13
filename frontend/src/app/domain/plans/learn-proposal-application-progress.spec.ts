import { describe, expect, it } from 'vitest';

import {
  bpTimingProposalKey,
  buildLearnProposalProgressItems,
  markProposalApplied,
  readAppliedProposalKeys,
  stageGddProposalKey
} from './learn-proposal-application-progress';
import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import type { StageGddCalibrationProposal } from './stage-gdd-calibration-proposal';

const stageGddProposal: StageGddCalibrationProposal = {
  cropId: 3,
  cropName: 'Tomato',
  stageId: 12,
  stageOrder: 2,
  stageName: 'Vegetative',
  averageGddDelta: 15,
  recordedItemCount: 4,
  currentRequiredGdd: 200,
  proposedRequiredGdd: 215
};

const bpTimingProposal: BlueprintTimingAdjustmentProposal = {
  cropId: 3,
  cropName: 'Tomato',
  category: 'general',
  averageDeltaDays: 3,
  averageGddDelta: 12,
  recordedItemCount: 5,
  affectedBlueprintCount: 2,
  proposalBody: {
    intent: 'blueprint_timing_patch',
    stages: [],
    agricultural_tasks: [],
    task_schedule_blueprints: []
  }
};

describe('learn-proposal-application-progress', () => {
  it('builds progress items with not_started status by default', () => {
    const items = buildLearnProposalProgressItems([stageGddProposal], [bpTimingProposal], new Set());

    expect(items).toHaveLength(2);
    expect(items[0]).toMatchObject({
      kind: 'stage_gdd',
      key: stageGddProposalKey(3, 12),
      cropName: 'Tomato',
      detailLabel: 'Vegetative',
      status: 'not_started'
    });
    expect(items[1]).toMatchObject({
      kind: 'bp_timing',
      key: bpTimingProposalKey(3, 'general'),
      status: 'not_started'
    });
  });

  it('marks applied keys as applied_pending_confirmation', () => {
    const applied = new Set([stageGddProposalKey(3, 12)]);
    const items = buildLearnProposalProgressItems([stageGddProposal], [bpTimingProposal], applied);

    expect(items[0]?.status).toBe('applied_pending_confirmation');
    expect(items[1]?.status).toBe('not_started');
  });

  it('persists applied proposal keys in session storage', () => {
    const storage = createMemoryStorage();

    markProposalApplied(7, stageGddProposalKey(3, 12), storage);
    markProposalApplied(7, bpTimingProposalKey(3, 'general'), storage);

    expect(readAppliedProposalKeys(7, storage)).toEqual(
      new Set([stageGddProposalKey(3, 12), bpTimingProposalKey(3, 'general')])
    );
  });
});

function createMemoryStorage(): Storage {
  const map = new Map<string, string>();
  return {
    get length() {
      return map.size;
    },
    clear() {
      map.clear();
    },
    getItem(key: string) {
      return map.get(key) ?? null;
    },
    key(index: number) {
      return [...map.keys()][index] ?? null;
    },
    removeItem(key: string) {
      map.delete(key);
    },
    setItem(key: string, value: string) {
      map.set(key, value);
    }
  };
}
