import { chromium } from 'playwright';

const OUT = new URL('e2e/agent-review/out/crops.logged-in.png', import.meta.url);
const returnTo = encodeURIComponent('http://localhost:4200/crops');
const loginUrl = `http://localhost:3000/auth/test/mock_login_as/developer?return_to=${returnTo}`;

const browser = await chromium.launch();
const context = await browser.newContext();
const page = await context.newPage();

try {
  await page.goto(loginUrl, { waitUntil: 'networkidle', timeout: 120_000 });
  await page.waitForURL(/\/\/localhost:4200\/crops/, { timeout: 60_000 });
  await page.locator('app-crop-list').waitFor({ state: 'visible', timeout: 60_000 });
  await page.waitForTimeout(2500);
  await page.screenshot({ path: OUT.pathname, fullPage: true });
  console.log('OK:', OUT.pathname);
} finally {
  await browser.close();
}
