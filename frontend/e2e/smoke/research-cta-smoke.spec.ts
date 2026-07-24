import { expect, test } from '@playwright/test';

const SAMPLE_DESKTOP_PAGE =
  '/research/research_reports/tomato/01_environmental_requirements/temperature_requirements.html';
const SAMPLE_MOBILE_PAGE =
  '/research/en/research_reports/tomato/01_environmental_requirements/gdd_requirements.html';

test.describe('research requirements CTA (static HTML)', () => {
  test('desktop: sidebar CTA visible with crop slug link', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 900 });
    await page.goto(SAMPLE_DESKTOP_PAGE, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(1500);

    const sidebarCta = page.locator('.agrr-research-sidebar-cta');
    await expect(sidebarCta).toBeVisible();
    const href = await sidebarCta.locator('a').first().getAttribute('href');
    expect(href).toMatch(/crop=tomato/);

    const inlineCta = page.locator('.vp-doc .agrr-gdd-simulate-cta').first();
    if ((await inlineCta.count()) > 0) {
      await expect(inlineCta).toBeHidden();
    }
  });

  test('mobile: floating bar visible with crop slug link', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto(SAMPLE_MOBILE_PAGE, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(1500);

    const mobileCta = page.locator('.agrr-research-mobile-cta');
    await expect(mobileCta).toBeVisible();
    const display = await mobileCta.evaluate((el) => getComputedStyle(el).display);
    expect(display).toBe('flex');

    const href = await mobileCta.locator('a').first().getAttribute('href');
    expect(href).toMatch(/crop=tomato/);
  });

  test('desktop: sidebar CTA navigates directly without VitePress 404 intermediates', async ({
    page,
    context,
  }) => {
    await page.setViewportSize({ width: 1280, height: 900 });
    await page.goto(SAMPLE_DESKTOP_PAGE, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(1500);

    const popupPromise = context.waitForEvent('page');
    await page.locator('.agrr-research-sidebar-cta a').first().click();
    const popup = await popupPromise;
    await popup.waitForLoadState('domcontentloaded');

    const finalUrl = new URL(popup.url());
    expect(finalUrl.pathname).toBe('/public-plans/new');
    expect(finalUrl.searchParams.get('crop')).toBe('tomato');
    expect(finalUrl.searchParams.get('utm_source')).toBe('research');
    expect(finalUrl.searchParams.get('utm_medium')).toBe('temp_sidebar');
    expect(finalUrl.pathname).not.toMatch(/\/public-plans\/new\.html/);
    await popup.close();
  });

  test('mobile: floating bar CTA navigates directly without VitePress 404 intermediates', async ({
    page,
    context,
  }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto(SAMPLE_MOBILE_PAGE, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(1500);

    const popupPromise = context.waitForEvent('page');
    await page.locator('.agrr-research-mobile-cta a').first().click();
    const popup = await popupPromise;
    await popup.waitForLoadState('domcontentloaded');

    const finalUrl = new URL(popup.url());
    expect(finalUrl.pathname).toBe('/public-plans/new');
    expect(finalUrl.searchParams.get('crop')).toBe('tomato');
    expect(finalUrl.searchParams.get('utm_medium')).toBe('temp_mobile');
    expect(finalUrl.pathname).not.toMatch(/\/public-plans\/new\.html/);
    await popup.close();
  });
});
