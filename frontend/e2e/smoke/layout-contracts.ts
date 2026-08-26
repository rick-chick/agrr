import type { Page } from '@playwright/test';

import { assertPublicPlanSelectCropStep2Layout } from '../assert-public-plan-select-crop-step2';
import { HOST_SELECTOR_BY_PATTERN } from '../route-validity';
import { assertPlanListLayout } from './assert-plan-list-layout';
import { LAYOUT_ARCHETYPE_RUNNERS } from './layout-contract-archetypes';
import {
  LAYOUT_CONTRACT_BY_PATTERN,
} from './layout-contract-bindings.mjs';
import { conformanceForPattern } from './layout-conformance-bindings.mjs';

type LayoutArchetype =
  | 'master-list'
  | 'master-detail'
  | 'master-form'
  | 'wizard-step'
  | 'plan-hub'
  | 'plan-form'
  | 'section-hub'
  | 'funnel-hub'
  | 'settings-page'
  | 'static-page'
  | 'l1-only';

export type LayoutContractOverride = (page: Page) => Promise<void>;

/**
 * Route-specific L2 contracts (override archetype binding).
 * Keys match route-manifest `pattern`.
 */
export const LAYOUT_CONTRACT_OVERRIDES: Partial<Record<string, LayoutContractOverride>> = {
  'public-plans/select-crop': assertPublicPlanSelectCropStep2Layout,
  plans: assertPlanListLayout,
};

function resolveHostSelector(page: Page, pattern: string): string | undefined {
  if (pattern === 'onboarding') {
    return page.url().includes('/onboarding') ? 'app-onboarding' : 'app-plan-list';
  }
  return HOST_SELECTOR_BY_PATTERN[pattern];
}

export async function runLayoutContract(page: Page, pattern: string): Promise<void> {
  const override = LAYOUT_CONTRACT_OVERRIDES[pattern];
  if (override) {
    await override(page);
    return;
  }

  const archetype = LAYOUT_CONTRACT_BY_PATTERN[pattern] as LayoutArchetype | undefined;
  if (!archetype || archetype === 'l1-only') {
    return;
  }

  const hostSelector = resolveHostSelector(page, pattern);
  if (!hostSelector) {
    throw new Error(`[layout-contract] no host selector for pattern "${pattern}"`);
  }

  const runner = LAYOUT_ARCHETYPE_RUNNERS[archetype];
  if (!runner) {
    throw new Error(`[layout-contract] no L2 runner registered for archetype "${archetype}"`);
  }

  const conformanceLevel = conformanceForPattern(pattern);
  await runner(page, hostSelector, conformanceLevel);
}
