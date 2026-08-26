/**
 * Layout contract bindings for every route-manifest pattern.
 *
 * Each pattern must appear here (archetype) or in LAYOUT_CONTRACT_EXEMPT (reason).
 * CI: `npm run e2e:layout-contract:check:enforce`
 */

/** @typedef {'master-list' | 'master-detail' | 'master-form' | 'wizard-step' | 'l1-only'} LayoutArchetype */

/** @type {Record<string, LayoutArchetype>} */
export const LAYOUT_CONTRACT_BY_PATTERN = {
  '': 'l1-only',
  about: 'l1-only',
  contact: 'l1-only',
  en: 'l1-only',
  'en/about': 'l1-only',
  'en/contact': 'l1-only',
  'en/privacy': 'l1-only',
  'en/public-plans/new': 'wizard-step',
  'en/terms': 'l1-only',
  'entry-schedule': 'l1-only',
  'entry-schedule/crop/:cropId': 'l1-only',
  privacy: 'l1-only',
  'public-plans/new': 'wizard-step',
  'public-plans/optimizing': 'wizard-step',
  'public-plans/results': 'wizard-step',
  'public-plans/select-crop': 'wizard-step',
  'public-plans/select-farm-size': 'wizard-step',
  terms: 'l1-only',
  account: 'l1-only',
  agricultural_tasks: 'master-list',
  'agricultural_tasks/:id': 'master-detail',
  'agricultural_tasks/:id/edit': 'master-form',
  'agricultural_tasks/new': 'master-form',
  'api-keys': 'l1-only',
  crops: 'master-list',
  'crops/:id': 'master-detail',
  'crops/:id/edit': 'master-form',
  'crops/:id/setup_proposal': 'l1-only',
  'crops/:id/stages': 'l1-only',
  'crops/:id/stages/:stageId/edit': 'master-form',
  'crops/:id/task_schedule_blueprints': 'l1-only',
  'crops/new': 'master-form',
  farms: 'master-list',
  'farms/:id': 'master-detail',
  'farms/:id/edit': 'master-form',
  'farms/new': 'master-form',
  fertilizes: 'master-list',
  'fertilizes/:id': 'master-detail',
  'fertilizes/:id/edit': 'master-form',
  'fertilizes/new': 'master-form',
  interaction_rules: 'master-list',
  'interaction_rules/:id': 'master-detail',
  'interaction_rules/:id/edit': 'master-form',
  'interaction_rules/new': 'master-form',
  onboarding: 'l1-only',
  pesticides: 'master-list',
  'pesticides/:id': 'master-detail',
  'pesticides/:id/edit': 'master-form',
  'pesticides/new': 'master-form',
  pests: 'master-list',
  'pests/:id': 'master-detail',
  'pests/:id/edit': 'master-form',
  'pests/new': 'master-form',
  plans: 'master-list',
  'plans/:id': 'l1-only',
  'plans/:id/learn': 'l1-only',
  'plans/:id/optimizing': 'l1-only',
  'plans/:id/task_schedule': 'l1-only',
  'plans/:id/work': 'l1-only',
  'plans/:id/work_records': 'l1-only',
  'plans/new': 'l1-only',
  work: 'l1-only',
  'work/variance': 'l1-only',
};

/** Patterns covered by L1 only; no L2 archetype runner (explicit classification). */
export const LAYOUT_ARCHETYPES = /** @type {const} */ ([
  'master-list',
  'master-detail',
  'master-form',
  'wizard-step',
  'l1-only',
]);

/**
 * Patterns with no L2 contract. Reason is shown in CI when a new route is missing from both maps.
 * @type {Record<string, string>}
 */
export const LAYOUT_CONTRACT_EXEMPT = {
  '**': 'intentional 404 fixture route',
  login: 'logged-out capture only; layout-smoke skips under dev session',
};
