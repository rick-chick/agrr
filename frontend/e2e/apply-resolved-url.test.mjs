import assert from 'node:assert/strict';
import { test } from 'node:test';

import { applyResolvedUrl } from './apply-resolved-url.mjs';

/** @type {import('./apply-resolved-url.mjs').ResolvedCaptureIds} */
const baseIds = {
  masters: { farms: 42, crops: 7, pesticides: 99 },
  privatePlanId: 12345,
  publicPlanId: 88,
  farmId: 42,
  cropId: 15,
  cropStageEdit: { cropId: 7, stageId: 31 },
};

test('applyResolvedUrl resolves all private plan sub-routes from baseline plan id', () => {
  const cases = [
    ['plans/:id', '/plans/1', '/plans/12345'],
    ['plans/:id/optimizing', '/plans/1/optimizing', '/plans/12345/optimizing'],
    ['plans/:id/task_schedule', '/plans/1/task_schedule', '/plans/12345/task_schedule'],
    ['plans/:id/work', '/plans/1/work', '/plans/12345/work'],
    ['plans/:id/work_records', '/plans/1/work_records', '/plans/12345/work_records'],
  ];
  for (const [pattern, url, expected] of cases) {
    assert.equal(applyResolvedUrl(pattern, url, baseIds), expected, pattern);
  }
});

test('applyResolvedUrl leaves plan url unchanged when privatePlanId is null', () => {
  const ids = { ...baseIds, privatePlanId: null };
  const url = '/plans/1/work';
  assert.equal(applyResolvedUrl('plans/:id/work', url, ids), url);
});

test('applyResolvedUrl does not partially replace multi-digit ids in unrelated paths', () => {
  const ids = { ...baseIds, privatePlanId: 12 };
  assert.equal(applyResolvedUrl('plans/:id/work', '/plans/1/work', ids), '/plans/12/work');
  assert.notEqual(applyResolvedUrl('plans/:id/work', '/plans/123/work', ids), '/plans/1123/work');
});

test('applyResolvedUrl resolves master detail and edit patterns', () => {
  assert.equal(
    applyResolvedUrl('farms/:id', '/farms/1', baseIds),
    '/farms/42',
  );
  assert.equal(
    applyResolvedUrl('crops/:id/edit', '/crops/1/edit', baseIds),
    '/crops/7/edit',
  );
});

test('applyResolvedUrl substitutes public plan query param', () => {
  const url = '/public-plans/results?planId=1';
  assert.equal(
    applyResolvedUrl('public-plans/results', url, baseIds),
    '/public-plans/results?planId=88',
  );
});

test('applyResolvedUrl leaves public plan url unchanged when publicPlanId is null', () => {
  const url = '/public-plans/results?planId=1';
  const ids = { ...baseIds, publicPlanId: null };
  assert.equal(applyResolvedUrl('public-plans/results', url, ids), url);
});

test('applyResolvedUrl builds entry-schedule crop url when cropId is known', () => {
  assert.equal(
    applyResolvedUrl('entry-schedule/crop/:cropId', '/entry-schedule/crop/1?farmId=1', baseIds),
    '/entry-schedule/crop/15?farmId=42',
  );
});

test('applyResolvedUrl leaves entry-schedule url unchanged when ids are missing', () => {
  const url = '/entry-schedule/crop/1?farmId=1';
  assert.equal(
    applyResolvedUrl('entry-schedule/crop/:cropId', url, { ...baseIds, cropId: null }),
    url,
  );
  assert.equal(
    applyResolvedUrl('entry-schedule/crop/:cropId', url, { ...baseIds, farmId: null }),
    url,
  );
});

test('applyResolvedUrl resolves crop stages list and stage edit routes', () => {
  assert.equal(
    applyResolvedUrl('crops/:id/stages', '/crops/1/stages', baseIds),
    '/crops/7/stages',
  );
  assert.equal(
    applyResolvedUrl('crops/:id/stages/:stageId/edit', '/crops/1/stages/1/edit', baseIds),
    '/crops/7/stages/31/edit',
  );
});

test('applyResolvedUrl leaves crop stage routes unchanged when cropStageEdit is null', () => {
  const ids = { ...baseIds, cropStageEdit: null };
  assert.equal(applyResolvedUrl('crops/:id/stages', '/crops/1/stages', ids), '/crops/1/stages');
  assert.equal(
    applyResolvedUrl('crops/:id/stages/:stageId/edit', '/crops/1/stages/1/edit', ids),
    '/crops/1/stages/1/edit',
  );
});

test('applyResolvedUrl returns original url for unknown patterns', () => {
  const url = '/about';
  assert.equal(applyResolvedUrl('about', url, baseIds), url);
});
