import assert from 'node:assert/strict';
import { test } from 'node:test';

import { buildSegmentPostBody, topLevelWrapperKey } from './ensure-e2e-baseline-bodies.mjs';

const SEGMENTS = [
  ['farms', 'farm'],
  ['crops', 'crop'],
  ['pests', 'pest'],
  ['pesticides', 'pesticide'],
  ['fertilizes', 'fertilize'],
  ['agricultural_tasks', 'agricultural_task'],
  ['interaction_rules', 'interaction_rule'],
];

test('buildSegmentPostBody wraps attrs in Rust masters API envelope', () => {
  const ctx = { cropId: 10, pestId: 20 };
  for (const [segment, wrapper] of SEGMENTS) {
    const body = buildSegmentPostBody(segment, ctx);
    assert.equal(topLevelWrapperKey(body), wrapper, segment);
    assert.ok(body[wrapper] != null && typeof body[wrapper] === 'object', segment);
  }
});

test('pesticides body includes crop_id and pest_id inside pesticide wrapper', () => {
  const body = buildSegmentPostBody('pesticides', { cropId: 3, pestId: 7 });
  assert.equal(body.pesticide.crop_id, 3);
  assert.equal(body.pesticide.pest_id, 7);
});
