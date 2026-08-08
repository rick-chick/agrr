/**
 * Agent 用空状態 PNG のファイル名（capture spec / verify で共有）。
 * @typedef {'farms-zero' | 'plans-zero' | 'crops-zero' | 'farm-no-fields'} EmptyStateScenario
 */

/** @type {readonly EmptyStateScenario[]} */
export const EMPTY_STATE_SCENARIOS = [
  'farms-zero',
  'plans-zero',
  'crops-zero',
  'farm-no-fields',
];

/**
 * @param {EmptyStateScenario} scenario
 * @param {'ja' | 'en' | 'in'} locale
 */
export function emptyStatePngFilename(scenario, locale) {
  return `empty-state_${scenario}.${locale}.png`;
}

/**
 * @param {EmptyStateScenario} scenario
 */
export function emptyStateRoutePath(scenario) {
  switch (scenario) {
    case 'farms-zero':
      return '/farms';
    case 'plans-zero':
      return '/plans';
    case 'crops-zero':
      return '/crops';
    case 'farm-no-fields':
      return '/plans/new';
    default:
      throw new Error(`unknown empty state scenario: ${scenario}`);
  }
}
