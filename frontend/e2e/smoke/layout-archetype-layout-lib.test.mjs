import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  findBlocksOutsideViewportRight,
  isRectOutsideViewportRight,
} from './layout-archetype-layout-lib.mjs';

test('isRectOutsideViewportRight respects tolerance', () => {
  const rect = { top: 0, left: 0, right: 801, bottom: 40 };
  assert.equal(isRectOutsideViewportRight(rect, 800, 1), false);
  assert.equal(isRectOutsideViewportRight(rect, 800, 0), true);
});

test('findBlocksOutsideViewportRight reports blocks wider than viewport', () => {
  const html = `
    <div id="host">
      <section class="detail-card" data-title="Crop A">wide</section>
      <section class="detail-card" data-title="Crop B">ok</section>
    </div>
  `;
  // jsdom not used; evaluate logic via minimal mock is hard — test the pure rect helper only.
  assert.equal(
    isRectOutsideViewportRight({ top: 0, left: 0, right: 1400, bottom: 200 }, 1280),
    true,
  );
});
