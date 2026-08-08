import assert from 'node:assert/strict';
import test from 'node:test';
import {
  filterUserOwnedRows,
  parseMasterList,
} from './empty-state-seed-lib.mjs';

test('parseMasterList accepts array or wrapped lists', () => {
  assert.deepEqual(parseMasterList([{ id: 1 }]), [{ id: 1 }]);
  assert.deepEqual(parseMasterList({ farms: [{ id: 2 }] }), [{ id: 2 }]);
  assert.deepEqual(parseMasterList({}), []);
});

test('filterUserOwnedRows excludes reference rows', () => {
  const rows = [
    { id: 1, is_reference: false },
    { id: 2, is_reference: true },
    { id: 3 },
  ];
  assert.deepEqual(filterUserOwnedRows(rows), [
    { id: 1, is_reference: false },
    { id: 3 },
  ]);
});
