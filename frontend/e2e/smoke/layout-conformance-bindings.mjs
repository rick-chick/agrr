/**
 * UI Conformance Level per route pattern (parallel to layout archetype bindings).
 *
 * Levels: L0 (SEO/a11y) … L4 (visual polish). See docs/design/UI-COMPOSITION-RULES.md
 * All route-manifest patterns must be listed when CI runs with --require-conformance-explicit.
 */

/** @typedef {'L0' | 'L1' | 'L2' | 'L3' | 'L4'} ConformanceLevel */

/** @type {Partial<Record<string, ConformanceLevel>>} */
export const LAYOUT_CONFORMANCE_BY_PATTERN = {
  '': 'L0',
  '**': 'L0',
  'about': 'L0',
  'account': 'L0',
  'agricultural_tasks': 'L0',
  'agricultural_tasks/:id': 'L0',
  'agricultural_tasks/:id/edit': 'L0',
  'agricultural_tasks/new': 'L0',
  'api-keys': 'L0',
  'contact': 'L0',
  'crops': 'L0',
  'crops/:id': 'L0',
  'crops/:id/edit': 'L0',
  'crops/:id/setup_proposal': 'L0',
  'crops/:id/stages': 'L0',
  'crops/:id/stages/:stageId/edit': 'L0',
  'crops/:id/task_schedule_blueprints': 'L0',
  'crops/new': 'L0',
  'en': 'L0',
  'en/about': 'L0',
  'en/contact': 'L0',
  'en/privacy': 'L0',
  'en/public-plans/new': 'L0',
  'en/terms': 'L0',
  'entry-schedule': 'L1',
  'entry-schedule/crop/:cropId': 'L1',
  'farms': 'L0',
  'farms/:id': 'L0',
  'farms/:id/edit': 'L0',
  'farms/new': 'L0',
  'fertilizes': 'L0',
  'fertilizes/:id': 'L0',
  'fertilizes/:id/edit': 'L0',
  'fertilizes/new': 'L0',
  'interaction_rules': 'L0',
  'interaction_rules/:id': 'L0',
  'interaction_rules/:id/edit': 'L0',
  'interaction_rules/new': 'L0',
  'login': 'L0',
  'onboarding': 'L0',
  'pesticides': 'L0',
  'pesticides/:id': 'L0',
  'pesticides/:id/edit': 'L0',
  'pesticides/new': 'L0',
  'pests': 'L0',
  'pests/:id': 'L0',
  'pests/:id/edit': 'L0',
  'pests/new': 'L0',
  'plans': 'L0',
  'plans/:id': 'L0',
  'plans/:id/learn': 'L0',
  'plans/:id/optimizing': 'L0',
  'plans/:id/task_schedule': 'L0',
  'plans/:id/work': 'L0',
  'plans/:id/work_records': 'L0',
  'plans/new': 'L0',
  'privacy': 'L0',
  'public-plans/new': 'L0',
  'public-plans/optimizing': 'L0',
  'public-plans/results': 'L0',
  'public-plans/select-crop': 'L0',
  'public-plans/select-farm-size': 'L0',
  'terms': 'L0',
  'work': 'L0',
  'work/variance': 'L0',
};

/** @type {readonly ConformanceLevel[]} */
export const CONFORMANCE_LEVELS = ['L0', 'L1', 'L2', 'L3', 'L4'];

/**
 * @param {string} pattern
 * @param {Partial<Record<string, ConformanceLevel>>} [overrides]
 * @returns {ConformanceLevel}
 */
export function conformanceForPattern(pattern, overrides = LAYOUT_CONFORMANCE_BY_PATTERN) {
  return overrides[pattern] ?? 'L0';
}

/**
 * @param {object} input
 * @param {string[]} input.manifestPatterns
 * @param {Partial<Record<string, ConformanceLevel>>} input.conformanceMap
 * @param {boolean} [input.requireExplicit]
 */
export function checkConformanceCoverage({
  manifestPatterns,
  conformanceMap,
  requireExplicit = false,
}) {
  const missing = requireExplicit
    ? manifestPatterns.filter((pattern) => conformanceMap[pattern] === undefined)
    : [];

  const manifestSet = new Set(manifestPatterns);
  const extraConformance = Object.keys(conformanceMap).filter(
    (pattern) => !manifestSet.has(pattern),
  );

  const invalidLevels = Object.entries(conformanceMap).filter(
    ([, level]) => !CONFORMANCE_LEVELS.includes(level),
  );

  return {
    ok: missing.length === 0 && extraConformance.length === 0 && invalidLevels.length === 0,
    missing,
    extraConformance,
    invalidLevels,
    manifestCount: manifestPatterns.length,
    conformanceCount: Object.keys(conformanceMap).length,
  };
}
