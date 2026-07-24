import { expect, test } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { listResearchRequirementsHtmlPaths } from '../../../scripts/research-simulate-cta-lib.mjs';

const RESEARCH_DIR = join(process.cwd(), '..', 'public', 'research');
const REQUIREMENT_PAGES = listResearchRequirementsHtmlPaths(RESEARCH_DIR);

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

  test('all 60 requirement pages load CTA script', () => {
    for (const relativePath of REQUIREMENT_PAGES) {
      const content = readFileSync(join(RESEARCH_DIR, relativePath), 'utf8');
      expect(content).toContain('agrr-gdd-simulate-cta.js');
    }
  });
});
