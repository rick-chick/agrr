/** Archetypes that require a Playwright L2 runner (excludes `l1-only`). */
export const LAYOUT_ARCHETYPE_RUNNER_KEYS = /** @type {const} */ ([
  'master-list',
  'master-detail',
  'master-form',
  'wizard-step',
  'plan-hub',
  'plan-form',
  'section-hub',
  'funnel-hub',
  'settings-page',
  'static-page',
]);

/** @typedef {(typeof LAYOUT_ARCHETYPE_RUNNER_KEYS)[number]} LayoutArchetypeRunnerKey */
