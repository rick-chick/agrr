import { describe, expect, it } from 'vitest';

import {
  LEARN_FOLLOW_UP_POST_MASTER,
  clearLearnPostMasterContext,
  isLearnPostMasterFollowUp,
  learnPostMasterPath,
  learnPostMasterQueryParams,
  readLearnPostMasterContext,
  writeLearnPostMasterContext
} from './learn-post-master-follow-up';

describe('learn-post-master-follow-up', () => {
  it('detects post_master follow-up query param', () => {
    expect(isLearnPostMasterFollowUp(LEARN_FOLLOW_UP_POST_MASTER)).toBe(true);
    expect(isLearnPostMasterFollowUp('other')).toBe(false);
    expect(isLearnPostMasterFollowUp(null)).toBe(false);
  });

  it('builds learn post_master navigation target', () => {
    expect(learnPostMasterPath(7)).toEqual(['/plans', 7, 'learn']);
    expect(learnPostMasterQueryParams()).toEqual({ followUp: LEARN_FOLLOW_UP_POST_MASTER });
  });

  it('stores and reads post_master context', () => {
    const storage = createMemoryStorage();
    writeLearnPostMasterContext(
      7,
      { kind: 'stage_gdd', cropName: 'Tomato', detailLabel: 'Vegetative' },
      storage
    );

    expect(readLearnPostMasterContext(7, storage)).toEqual({
      kind: 'stage_gdd',
      cropName: 'Tomato',
      detailLabel: 'Vegetative'
    });

    clearLearnPostMasterContext(7, storage);
    expect(readLearnPostMasterContext(7, storage)).toBeNull();
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
