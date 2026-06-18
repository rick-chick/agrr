import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { firstRecordId, pickEntryScheduleCropId } from './entry-schedule-ids-lib.mjs';

describe('entry-schedule-ids-lib', () => {
  it('firstRecordId returns first object with id', () => {
    assert.equal(firstRecordId([{ name: 'x' }, { id: 42 }]), 42);
  });

  it('firstRecordId returns null for empty or invalid input', () => {
    assert.equal(firstRecordId([]), null);
    assert.equal(firstRecordId(null), null);
    assert.equal(firstRecordId([{ name: 'no-id' }]), null);
  });

  it('pickEntryScheduleCropId reads crops array', () => {
    assert.equal(pickEntryScheduleCropId({ crops: [{ id: 7 }] }), 7);
  });

  it('pickEntryScheduleCropId returns null when crops missing', () => {
    assert.equal(pickEntryScheduleCropId({}), null);
    assert.equal(pickEntryScheduleCropId({ crops: [] }), null);
  });
});
