import type { Page } from '@playwright/test';

import { HOST_SELECTOR_BY_PATTERN, type RouteRow } from '../route-validity';
import {
  LAYOUT_ALLOW_DOCUMENT_HORIZONTAL_OVERFLOW,
  LAYOUT_ALLOW_VISIBLE_MASTER_LOADING,
  LAYOUT_SKIP_LEVEL_ONE_HEADING,
} from './layout-smoke-lib.mjs';
import { assertPageLayoutInvariants } from './layout-invariants';
import { runLayoutContract } from './layout-contracts';

/** Run L1 invariants + L2 route contract after page is stable (capture + smoke shared). */
export async function assertRouteLayoutAfterStable(page: Page, route: RouteRow): Promise<void> {
  const hostSelector =
    route.pattern === 'onboarding'
      ? page.url().includes('/onboarding')
        ? 'app-onboarding'
        : 'app-plan-list'
      : HOST_SELECTOR_BY_PATTERN[route.pattern];

  await assertPageLayoutInvariants(page, {
    hostSelector,
    allowDocumentHorizontalOverflow: LAYOUT_ALLOW_DOCUMENT_HORIZONTAL_OVERFLOW.has(route.pattern),
    allowVisibleMasterLoading: LAYOUT_ALLOW_VISIBLE_MASTER_LOADING.has(route.pattern),
    requireLevelOneHeading: !LAYOUT_SKIP_LEVEL_ONE_HEADING.has(route.pattern),
  });

  await runLayoutContract(page, route.pattern);
}
