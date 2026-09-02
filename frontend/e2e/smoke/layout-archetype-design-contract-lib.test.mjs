import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  LAYOUT_ARCHETYPE_DESIGN_CONTRACTS,
} from './layout-archetype-design-contracts.mjs';
import {
  checkContentBlockLayout,
  countVisibleMatches,
  maxActionButtonRowsForViewport,
} from './layout-archetype-design-contract-lib.mjs';
import { LAYOUT_ARCHETYPE_RUNNER_KEYS } from './layout-contract-archetype-keys.mjs';

test('checkContentBlockLayout fails when requireAnyContentBlock and no blocks match', async () => {
  const html = `
    <div id="host">
      <p class="unrelated">empty shell</p>
    </div>
  `;

  const violations = await checkContentBlockLayout({
    html,
    hostSelector: '#host',
    viewportWidth: 1280,
    contract: {
      contentBlockSelectors: ['.section-card'],
      requireAnyContentBlock: true,
    },
  });

  assert.ok(violations.some((v) => v.includes('requireAnyContentBlock')));
});

test('checkContentBlockLayout reports viewport overflow for matched blocks', async () => {
  const html = `
    <div id="host">
      <section class="section-card" style="width: 1400px; height: 40px; display: block;"></section>
    </div>
  `;

  const violations = await checkContentBlockLayout({
    html,
    hostSelector: '#host',
    viewportWidth: 1280,
    contract: {
      contentBlockSelectors: ['.section-card'],
      requireAnyContentBlock: true,
    },
  });

  assert.ok(violations.some((v) => v.includes('viewport')));
});

test('checkContentBlockLayout enforces maxItemCardVisibleActionButtons', async () => {
  const html = `
    <div id="host">
      <article class="item-card">
        <div class="item-card__actions">
          <button class="btn" style="width: 40px; height: 32px; display: inline-block;">A</button>
          <button class="btn" style="width: 40px; height: 32px; display: inline-block;">B</button>
          <button class="btn" style="width: 40px; height: 32px; display: inline-block;">C</button>
          <button class="btn" style="width: 40px; height: 32px; display: inline-block;">D</button>
        </div>
      </article>
    </div>
  `;

  const violations = await checkContentBlockLayout({
    html,
    hostSelector: '#host',
    viewportWidth: 1280,
    contract: {
      contentBlockSelectors: ['.item-card'],
      requireAnyContentBlock: true,
      maxItemCardVisibleActionButtons: 3,
    },
  });

  assert.ok(violations.some((v) => v.includes('maxItemCardVisibleActionButtons')));
});

test('checkContentBlockLayout enforces requiredShellSelectors for L1 conformance', async () => {
  const html = `
    <div id="host">
      <section class="content-card" data-width="400" data-height="40" style="display: block;"></section>
    </div>
  `;

  const violations = await checkContentBlockLayout({
    html,
    hostSelector: '#host',
    viewportWidth: 1280,
    conformanceLevel: 'L1',
    contract: {
      contentBlockSelectors: ['.content-card'],
      requireAnyContentBlock: true,
      requiredShellSelectors: ['app-funnel-shell'],
    },
  });

  assert.ok(violations.some((v) => v.includes('requiredShellSelectors')));
});

test('checkContentBlockLayout skips requiredShellSelectors for L0 conformance', async () => {
  const html = `
    <div id="host">
      <section class="content-card" data-width="400" data-height="40" style="display: block;"></section>
    </div>
  `;

  const violations = await checkContentBlockLayout({
    html,
    hostSelector: '#host',
    viewportWidth: 1280,
    conformanceLevel: 'L0',
    contract: {
      contentBlockSelectors: ['.content-card'],
      requireAnyContentBlock: true,
      requiredShellSelectors: ['app-funnel-shell'],
    },
  });

  assert.equal(violations.some((v) => v.includes('requiredShellSelectors')), false);
});

test('LAYOUT_ARCHETYPE_DESIGN_CONTRACTS covers every L2 runner key', () => {
  for (const key of LAYOUT_ARCHETYPE_RUNNER_KEYS) {
    assert.ok(
      LAYOUT_ARCHETYPE_DESIGN_CONTRACTS[key],
      `missing design contract for archetype "${key}"`,
    );
  }
});

test('wizard-step and funnel-hub share wizardProgressSelectors from assert-wizard-progress-lib', () => {
  const wizardStep = LAYOUT_ARCHETYPE_DESIGN_CONTRACTS['wizard-step'];
  const funnelHub = LAYOUT_ARCHETYPE_DESIGN_CONTRACTS['funnel-hub'];
  assert.deepEqual(wizardStep.wizardProgressSelectors, ['.compact-progress']);
  assert.deepEqual(funnelHub.wizardProgressSelectors, ['.compact-progress']);
  assert.equal(wizardStep.wizardProgressMinHeightPx, 40);
  assert.equal(funnelHub.wizardProgressMinHeightPx, 40);
});

test('maxActionButtonRowsForViewport matches layout invariant tiers', () => {
  assert.equal(maxActionButtonRowsForViewport(390), 4);
  assert.equal(maxActionButtonRowsForViewport(768), 3);
  assert.equal(maxActionButtonRowsForViewport(1280), 2);
});

test('checkContentBlockLayout enforces wizardProgressSelectors flex and min-height', async () => {
  const html = `
    <div id="host">
      <div class="compact-progress" style="display: block; width: 200px; height: 44px;"></div>
    </div>
  `;

  const violations = await checkContentBlockLayout({
    html,
    hostSelector: '#host',
    viewportWidth: 1280,
    contract: {
      contentBlockSelectors: ['.content-card'],
      requireAnyContentBlock: false,
      wizardProgressSelectors: ['.compact-progress'],
      wizardProgressMinHeightPx: 40,
    },
  });

  assert.ok(violations.some((v) => v.includes('display=block')));
});

test('checkContentBlockLayout reports wizardProgressSelectors below min-height', async () => {
  const html = `
    <div id="host">
      <div class="compact-progress" style="display: flex; width: 200px; height: 32px;"></div>
    </div>
  `;

  const violations = await checkContentBlockLayout({
    html,
    hostSelector: '#host',
    viewportWidth: 1280,
    contract: {
      contentBlockSelectors: ['.content-card'],
      requireAnyContentBlock: false,
      wizardProgressSelectors: ['.compact-progress'],
      wizardProgressMinHeightPx: 40,
    },
  });

  assert.ok(violations.some((v) => v.includes('height=32.0px < 40px')));
});
