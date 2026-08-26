import type { Page } from '@playwright/test';

import { assertArchetypeDesignContract } from './layout-archetype-assertions';
import { LAYOUT_ARCHETYPE_DESIGN_CONTRACTS } from './layout-archetype-design-contracts.mjs';
import { LAYOUT_ARCHETYPE_RUNNER_KEYS } from './layout-contract-archetype-keys.mjs';

export type LayoutContract = (page: Page, hostSelector: string) => Promise<void>;

function runnerForArchetype(
  key: (typeof LAYOUT_ARCHETYPE_RUNNER_KEYS)[number],
): LayoutContract {
  const contract = LAYOUT_ARCHETYPE_DESIGN_CONTRACTS[key];
  return (page, hostSelector) => assertArchetypeDesignContract(page, hostSelector, contract);
}

export const LAYOUT_ARCHETYPE_RUNNERS: Record<
  (typeof LAYOUT_ARCHETYPE_RUNNER_KEYS)[number],
  LayoutContract
> = Object.fromEntries(
  LAYOUT_ARCHETYPE_RUNNER_KEYS.map((key) => [key, runnerForArchetype(key)]),
) as Record<(typeof LAYOUT_ARCHETYPE_RUNNER_KEYS)[number], LayoutContract>;
