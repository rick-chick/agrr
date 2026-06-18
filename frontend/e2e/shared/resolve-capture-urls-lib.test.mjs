import assert from 'node:assert/strict';
import { test } from 'node:test';

import { applyResolvedUrl } from './resolve-capture-urls-lib.mjs';

const baseIds = {
  masters: { crops: 55, farms: 3, pesticides: 901 },
  privatePlanId: 77,
  publicPlanId: 12,
  farmId: 3,
  cropId: 44,
};

test('applyResolvedUrl resolves plans/:id/work and work_records with baseline plan id', () => {
  assert.equal(
    applyResolvedUrl('plans/:id/work', '/plans/1/work', baseIds),
    '/plans/77/work',
  );
  assert.equal(
    applyResolvedUrl('plans/:id/work_records', '/plans/1/work_records', baseIds),
    '/plans/77/work_records',
  );
});

test('applyResolvedUrl resolves other plan sub-routes from pattern not substring replace', () => {
  assert.equal(applyResolvedUrl('plans/:id', '/plans/1', baseIds), '/plans/77');
  assert.equal(
    applyResolvedUrl('plans/:id/optimizing', '/plans/1/optimizing', baseIds),
    '/plans/77/optimizing',
  );
  assert.equal(
    applyResolvedUrl('plans/:id/task_schedule', '/plans/1/task_schedule', baseIds),
    '/plans/77/task_schedule',
  );
});

test('applyResolvedUrl leaves plan url unchanged when privatePlanId is null', () => {
  const ids = { ...baseIds, privatePlanId: null };
  assert.equal(applyResolvedUrl('plans/:id/work', '/plans/1/work', ids), '/plans/1/work');
});

test('applyResolvedUrl does not mis-resolve multi-digit ids via partial replace', () => {
  const ids = { ...baseIds, privatePlanId: 100 };
  assert.equal(
    applyResolvedUrl('plans/:id/work', '/plans/1/work', ids),
    '/plans/100/work',
  );
});

test('applyResolvedUrl resolves master detail and edit routes', () => {
  assert.equal(applyResolvedUrl('crops/:id', '/crops/1', baseIds), '/crops/55');
  assert.equal(applyResolvedUrl('crops/:id/edit', '/crops/1/edit', baseIds), '/crops/55/edit');
});

test('applyResolvedUrl leaves master url when id is unresolved', () => {
  const ids = { ...baseIds, masters: {} };
  assert.equal(applyResolvedUrl('crops/:id', '/crops/1', ids), '/crops/1');
});

test('applyResolvedUrl resolves public-plans planId query param', () => {
  assert.equal(
    applyResolvedUrl('public-plans/results', '/public-plans/results?planId=1', baseIds),
    '/public-plans/results?planId=12',
  );
});

test('applyResolvedUrl resolves entry-schedule crop with farm query', () => {
  assert.equal(
    applyResolvedUrl('entry-schedule/crop/:cropId', '/entry-schedule/crop/1?farmId=1', baseIds),
    '/entry-schedule/crop/44?farmId=3',
  );
});

test('applyResolvedUrl keeps entry-schedule url when cropId is null', () => {
  const ids = { ...baseIds, cropId: null };
  const url = '/entry-schedule/crop/1?farmId=1';
  assert.equal(applyResolvedUrl('entry-schedule/crop/:cropId', url, ids), url);
});

test('applyResolvedUrl returns url unchanged for unknown patterns', () => {
  assert.equal(applyResolvedUrl('about', '/about', baseIds), '/about');
});
