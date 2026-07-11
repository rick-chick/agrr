import type { Page } from '@playwright/test';

import {
  buildPublicPlanSessionState,
  PUBLIC_PLAN_SESSION_STORAGE_KEY,
} from './seed-public-plan-session.mjs';

export type SeedPublicPlanFarm = {
  id: number;
  name: string;
  region: string;
  latitude?: number;
  longitude?: number;
};

export { buildPublicPlanSessionState, PUBLIC_PLAN_SESSION_STORAGE_KEY };

/** select-crop 直着地キャプチャ用: sessionStorage に farm を事前投入する */
export async function seedPublicPlanFarmSession(
  page: Page,
  farm: SeedPublicPlanFarm,
): Promise<void> {
  const state = buildPublicPlanSessionState(farm);
  await page.addInitScript((storageKey, serialized) => {
    sessionStorage.setItem(storageKey, serialized);
  }, PUBLIC_PLAN_SESSION_STORAGE_KEY, JSON.stringify(state));
}
