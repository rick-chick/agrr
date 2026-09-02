/**
 * Layout archetype design contracts — single source for L2 structural + density rules.
 *
 * Human-readable overview: docs/design/layout-contracts.md
 */

/** @typedef {object} LayoutArchetypeDesignContract
 * @property {string[]} contentBlockSelectors Blocks checked for presence and horizontal overflow.
 * @property {boolean} requireAnyContentBlock Fail when zero visible blocks match contentBlockSelectors.
 * @property {string[]} [pageTitleSelectors] At least one visible match required.
 * @property {string[]} [conditionalVisibleSelectors] If present in host, must be visible.
 * @property {number} [maxItemCardVisibleActionButtons] Visible `.btn` count per `.item-card__actions`.
 * @property {boolean} [checkFormCardActionRows] Enforce viewport-tier row limits on `.form-card__actions`.
 * @property {boolean} [checkDetailCardActionOverlap] Forbid overlapping buttons in `.detail-card__actions`.
 * @property {string[]} [requiredShellSelectors] Host must contain selector when conformance is L1+.
 * @property {string[]} [wizardProgressSelectors] Wizard step progress bars: flex + min-height density.
 */

import { DEFAULT_WIZARD_PROGRESS_SELECTORS } from './wizard-progress-contract.mjs';

/** @type {Record<import('./layout-contract-archetype-keys.mjs').LayoutArchetypeRunnerKey, LayoutArchetypeDesignContract>} */
export const LAYOUT_ARCHETYPE_DESIGN_CONTRACTS = {
  'master-list': {
    contentBlockSelectors: ['.item-card'],
    requireAnyContentBlock: false,
    maxItemCardVisibleActionButtons: 3,
  },
  'master-detail': {
    contentBlockSelectors: ['.detail-card'],
    requireAnyContentBlock: true,
    checkDetailCardActionOverlap: true,
  },
  'master-form': {
    contentBlockSelectors: ['.form-card'],
    requireAnyContentBlock: true,
    checkFormCardActionRows: true,
  },
  'wizard-step': {
    contentBlockSelectors: [
      '.free-plans-container',
      '.public-plans-wrapper',
      '.plan-detail-surface',
      '.public-plan-results__body',
      'app-public-plan-optimizing',
    ],
    requireAnyContentBlock: true,
    pageTitleSelectors: ['h1', 'h2', '.page-title'],
    wizardProgressSelectors: [...DEFAULT_WIZARD_PROGRESS_SELECTORS],
  },
  'plan-hub': {
    contentBlockSelectors: [
      '.section-card',
      '.plan-detail__body',
      '.plan-detail-surface',
      '.plan-detail__alert',
      '.page-alert-error',
    ],
    requireAnyContentBlock: true,
    conditionalVisibleSelectors: ['app-plan-plan-context-header'],
  },
  'plan-form': {
    contentBlockSelectors: ['.section-card'],
    requireAnyContentBlock: true,
    pageTitleSelectors: ['#page-title', '.page-title'],
  },
  'section-hub': {
    contentBlockSelectors: [
      '.section-card',
      '.work-hub__portfolio-summary',
      '.work-hub-empty',
      '.content-card',
    ],
    requireAnyContentBlock: true,
  },
  'funnel-hub': {
    contentBlockSelectors: [
      '.content-card',
      'app-funnel-shell',
      '.free-plans-container',
    ],
    requireAnyContentBlock: true,
    pageTitleSelectors: ['h1', '.compact-header-title'],
    requiredShellSelectors: ['app-funnel-shell'],
    wizardProgressSelectors: [...DEFAULT_WIZARD_PROGRESS_SELECTORS],
  },
  'settings-page': {
    contentBlockSelectors: ['.info-box', '.page-content'],
    requireAnyContentBlock: true,
    pageTitleSelectors: ['h1'],
  },
  'static-page': {
    contentBlockSelectors: ['.page-content', '.page-section', '.hero-section', '.features-section'],
    requireAnyContentBlock: true,
    pageTitleSelectors: ['h1', '.page-title'],
  },
};
