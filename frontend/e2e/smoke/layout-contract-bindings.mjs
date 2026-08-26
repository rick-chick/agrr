/**
 * Layout contract bindings for every route-manifest pattern.
 *
 * Each pattern must appear here (archetype) or in LAYOUT_CONTRACT_EXEMPT (reason).
 * CI: `npm run e2e:layout-contract:check:enforce`
 */

/** @typedef {'master-list' | 'master-detail' | 'master-form' | 'wizard-step' | 'plan-hub' | 'plan-form' | 'section-hub' | 'settings-page' | 'static-page' | 'l1-only'} LayoutArchetype */

/** @type {Record<string, LayoutArchetype>} */
export const LAYOUT_CONTRACT_BY_PATTERN = {
  '': 'static-page',
  about: 'static-page',
  contact: 'static-page',
  en: 'static-page',
  'en/about': 'static-page',
  'en/contact': 'static-page',
  'en/privacy': 'static-page',
  'en/public-plans/new': 'wizard-step',
  'en/terms': 'static-page',
  'entry-schedule': 'section-hub',
  'entry-schedule/crop/:cropId': 'section-hub',
  privacy: 'static-page',
  'public-plans/new': 'wizard-step',
  'public-plans/optimizing': 'wizard-step',
  'public-plans/results': 'wizard-step',
  'public-plans/select-crop': 'wizard-step',
  'public-plans/select-farm-size': 'wizard-step',
  terms: 'static-page',
  account: 'settings-page',
  agricultural_tasks: 'master-list',
  'agricultural_tasks/:id': 'master-detail',
  'agricultural_tasks/:id/edit': 'master-form',
  'agricultural_tasks/new': 'master-form',
  'api-keys': 'settings-page',
  crops: 'master-list',
  'crops/:id': 'master-detail',
  'crops/:id/edit': 'master-form',
  'crops/:id/setup_proposal': 'master-form',
  'crops/:id/stages': 'section-hub',
  'crops/:id/stages/:stageId/edit': 'master-form',
  'crops/:id/task_schedule_blueprints': 'section-hub',
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
  onboarding: 'plan-form',
  pesticides: 'master-list',
  'pesticides/:id': 'master-detail',
  'pesticides/:id/edit': 'master-form',
  'pesticides/new': 'master-form',
  pests: 'master-list',
  'pests/:id': 'master-detail',
  'pests/:id/edit': 'master-form',
  'pests/new': 'master-form',
  plans: 'master-list',
  'plans/:id': 'plan-hub',
  'plans/:id/learn': 'plan-hub',
  'plans/:id/optimizing': 'plan-hub',
  'plans/:id/task_schedule': 'plan-hub',
  'plans/:id/work': 'plan-hub',
  'plans/:id/work_records': 'plan-hub',
  'plans/new': 'plan-form',
  work: 'section-hub',
  'work/variance': 'section-hub',
};

/** Patterns covered by L1 only; no L2 archetype runner (explicit classification). */
export const LAYOUT_ARCHETYPES = /** @type {const} */ ([
  'master-list',
  'master-detail',
  'master-form',
  'wizard-step',
  'plan-hub',
  'plan-form',
  'section-hub',
  'settings-page',
  'static-page',
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
