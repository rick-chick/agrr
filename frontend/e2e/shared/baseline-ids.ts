import {
  MASTER_SEGMENTS,
  E2E_BASELINE_PREFIX,
  parseMasterList,
  baselineLabel,
  firstIdFromList,
  findBaselineIdInList,
  pickBaselineIdFromList,
  pickBaselinePlanId,
  countUserOwnedFarms,
} from './baseline-ids-lib.mjs';

export {
  MASTER_SEGMENTS,
  E2E_BASELINE_PREFIX,
  parseMasterList,
  baselineLabel,
  firstIdFromList,
  findBaselineIdInList,
  pickBaselineIdFromList,
  pickBaselinePlanId,
  countUserOwnedFarms,
};

export type MasterSegment = (typeof MASTER_SEGMENTS)[number];

export type JsonRecord = Record<string, unknown>;
