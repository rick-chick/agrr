import { expect, type Page } from '@playwright/test';

import {
  PUBLIC_PLAN_CREATE_HOST,
  PUBLIC_PLAN_SELECT_CROP_STEP2_ACTIVE_STEP,
  PUBLIC_PLAN_SELECT_CROP_STEP2_CROP_ITEMS,
  PUBLIC_PLAN_SELECT_CROP_STEP2_HOST,
  PUBLIC_PLAN_SELECT_CROP_STEP2_NUMBER,
} from './assert-public-plan-select-crop-step2-lib.mjs';

/** スモーク: select-crop 直着地が step2 UI（step1 create 非表示）であること。作物0件でも通す */
export async function assertPublicPlanSelectCropStep2Layout(page: Page): Promise<void> {
  await expect(page).toHaveURL(/\/public-plans\/select-crop/);
  await expect(page.locator(PUBLIC_PLAN_CREATE_HOST)).toHaveCount(0);
  await expect(page.locator(PUBLIC_PLAN_SELECT_CROP_STEP2_HOST)).toBeVisible();
  await expect(page.locator(PUBLIC_PLAN_SELECT_CROP_STEP2_ACTIVE_STEP)).toHaveText(
    PUBLIC_PLAN_SELECT_CROP_STEP2_NUMBER,
  );
}

/** Agent キャプチャ前: select-crop が step2（作物選択）UI であることを保証する */
export async function assertPublicPlanSelectCropStep2(page: Page): Promise<void> {
  await assertPublicPlanSelectCropStep2Layout(page);
  await expect(page.locator(PUBLIC_PLAN_SELECT_CROP_STEP2_CROP_ITEMS).first()).toBeVisible();
}
