import { beforeEach, describe, expect, it } from 'vitest';
import {
  markLearnProposalConfirmed,
  markLearnProposalDismissed,
  markStageGddProposalAppliedPending,
  markAllConfirmedProposalsDone
} from '../../domain/plans/learn-proposal-application-progress';
import { buildLearnApplicationProgressItems } from './plan-learn-application-progress-view.component';

describe('buildLearnApplicationProgressItems', () => {
  beforeEach(() => {
    sessionStorage.clear();
  });

  it('returns not_started for proposals without stored progress', () => {
    const items = buildLearnApplicationProgressItems(
      7,
      [
        {
          cropId: 1,
          cropName: 'Tomato',
          stageId: 2,
          stageOrder: 1,
          stageName: 'Vegetative',
          averageGddDelta: 10,
          recordedItemCount: 3,
          currentRequiredGdd: 100,
          proposedRequiredGdd: 110
        }
      ],
      [
        {
          cropId: 1,
          cropName: 'Tomato',
          category: 'general',
          averageDeltaDays: 2,
          averageGddDelta: 5,
          recordedItemCount: 4,
          affectedBlueprintCount: 2,
          proposalBody: {
            stages: [],
            agricultural_tasks: [],
            task_schedule_blueprints: []
          }
        }
      ]
    );

    expect(items).toHaveLength(2);
    expect(items[0]).toMatchObject({
      kind: 'stage_gdd',
      title: 'Tomato — Vegetative',
      status: 'not_started'
    });
    expect(items[1]).toMatchObject({
      kind: 'bp_timing',
      title: 'Tomato — general',
      status: 'not_started'
    });
  });

  it('reflects confirmed and done statuses from session storage', () => {
    const key = 'stage_gdd:1:2';
    markStageGddProposalAppliedPending(7, { cropId: 1, stageId: 2 });
    markLearnProposalConfirmed(7, key);

    const confirmedItems = buildLearnApplicationProgressItems(
      7,
      [
        {
          cropId: 1,
          cropName: 'Tomato',
          stageId: 2,
          stageOrder: 1,
          stageName: 'Vegetative',
          averageGddDelta: 10,
          recordedItemCount: 3,
          currentRequiredGdd: 100,
          proposedRequiredGdd: 110
        }
      ],
      []
    );
    expect(confirmedItems[0]?.status).toBe('confirmed');

    markAllConfirmedProposalsDone(7);
    const doneItems = buildLearnApplicationProgressItems(
      7,
      [
        {
          cropId: 1,
          cropName: 'Tomato',
          stageId: 2,
          stageOrder: 1,
          stageName: 'Vegetative',
          averageGddDelta: 10,
          recordedItemCount: 3,
          currentRequiredGdd: 100,
          proposedRequiredGdd: 110
        }
      ],
      []
    );
    expect(doneItems[0]?.status).toBe('done');
  });

  it('reflects dismissed status from session storage', () => {
    markLearnProposalDismissed(7, 'stage_gdd:1:2');

    const items = buildLearnApplicationProgressItems(
      7,
      [
        {
          cropId: 1,
          cropName: 'Tomato',
          stageId: 2,
          stageOrder: 1,
          stageName: 'Vegetative',
          averageGddDelta: 10,
          recordedItemCount: 3,
          currentRequiredGdd: 100,
          proposedRequiredGdd: 110
        }
      ],
      []
    );

    expect(items[0]?.status).toBe('dismissed');
  });
});
