import { describe, expect, it } from 'vitest';
import type { CropStage } from '../crops/crop';
import { buildStageGddCalibrationProposals } from './build-stage-gdd-calibration-proposals';

const stages: CropStage[] = [
  {
    id: 501,
    crop_id: 42,
    name: 'Vegetative',
    order: 1,
    thermal_requirement: { id: 1, crop_stage_id: 501, required_gdd: 120 }
  },
  {
    id: 502,
    crop_id: 42,
    name: 'Flowering',
    order: 2,
    thermal_requirement: { id: 2, crop_stage_id: 502, required_gdd: 200 }
  }
];

describe('buildStageGddCalibrationProposals', () => {
  it('maps stage order to stage id and proposes adjusted required gdd', () => {
    const proposals = buildStageGddCalibrationProposals(
      [
        {
          crop_id: 42,
          crop_name: 'Tomato',
          stage_order: 1,
          stage_name: 'Vegetative',
          average_gdd_delta: 10.5,
          recorded_item_count: 2
        }
      ],
      new Map([[42, stages]])
    );

    expect(proposals).toEqual([
      {
        cropId: 42,
        cropName: 'Tomato',
        stageId: 501,
        stageOrder: 1,
        stageName: 'Vegetative',
        averageGddDelta: 10.5,
        recordedItemCount: 2,
        currentRequiredGdd: 120,
        proposedRequiredGdd: 130.5
      }
    ]);
  });

  it('skips proposals when stage is missing or delta is negligible', () => {
    const proposals = buildStageGddCalibrationProposals(
      [
        {
          crop_id: 42,
          crop_name: 'Tomato',
          stage_order: 9,
          stage_name: 'Unknown',
          average_gdd_delta: 5,
          recorded_item_count: 1
        },
        {
          crop_id: 42,
          crop_name: 'Tomato',
          stage_order: 2,
          stage_name: 'Flowering',
          average_gdd_delta: 0.01,
          recorded_item_count: 1
        }
      ],
      new Map([[42, stages]])
    );

    expect(proposals).toEqual([]);
  });
});
