import type { Page } from '@playwright/test';

import { assertMasterListLayout } from './assert-master-list-layout';
import { assertWizardStepLayout } from './assert-wizard-step-layout';
import { LAYOUT_ARCHETYPE_RUNNER_KEYS } from './layout-contract-archetype-keys.mjs';

export type LayoutContract = (page: Page, hostSelector: string) => Promise<void>;

export const LAYOUT_ARCHETYPE_RUNNERS: Record<
  (typeof LAYOUT_ARCHETYPE_RUNNER_KEYS)[number],
  LayoutContract
> = {
  'master-list': assertMasterListLayout,
  'wizard-step': assertWizardStepLayout,
};
