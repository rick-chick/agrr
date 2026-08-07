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

/** select-crop 直着地キャプチャ用: sessionStorage に farm を投入し store を再読込させる */
export async function seedPublicPlanFarmSession(
  page: Page,
  farm: SeedPublicPlanFarm,
): Promise<void> {
  const serialized = JSON.stringify(buildPublicPlanSessionState(farm));
  if (!serialized || serialized === 'undefined') {
    throw new Error(`seedPublicPlanFarmSession: invalid serialized state for farm id=${farm?.id}`);
  }

  await page.goto('/', { waitUntil: 'domcontentloaded' });
  const applied = await page.evaluate(
    ({ storageKey, value }) => {
      sessionStorage.setItem(storageKey, value);
      return sessionStorage.getItem(storageKey);
    },
    { storageKey: PUBLIC_PLAN_SESSION_STORAGE_KEY, value: serialized },
  );
  if (!applied || applied === 'undefined') {
    throw new Error(`seedPublicPlanFarmSession: sessionStorage apply failed (len=${serialized.length})`);
  }
  await page.reload({ waitUntil: 'domcontentloaded' });
}
