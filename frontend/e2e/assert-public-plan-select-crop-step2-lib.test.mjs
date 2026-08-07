import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  PUBLIC_PLAN_CREATE_HOST,
  PUBLIC_PLAN_SELECT_CROP_STEP2_ACTIVE_STEP,
  PUBLIC_PLAN_SELECT_CROP_STEP2_CROP_ITEMS,
  PUBLIC_PLAN_SELECT_CROP_STEP2_HOST,
  PUBLIC_PLAN_SELECT_CROP_STEP2_NUMBER,
} from './assert-public-plan-select-crop-step2-lib.mjs';

test('step2 capture markers target select-crop host and crop grid', () => {
  assert.match(PUBLIC_PLAN_SELECT_CROP_STEP2_HOST, /^app-public-plan-select-crop$/);
  assert.match(PUBLIC_PLAN_SELECT_CROP_STEP2_ACTIVE_STEP, /compact-step\.active/);
  assert.match(PUBLIC_PLAN_SELECT_CROP_STEP2_CROP_ITEMS, /crop-item/);
  assert.equal(PUBLIC_PLAN_SELECT_CROP_STEP2_NUMBER, '2');
  assert.notEqual(PUBLIC_PLAN_CREATE_HOST, PUBLIC_PLAN_SELECT_CROP_STEP2_HOST);
});
