/**
 * LHCI puppeteerScript: inject session cookies from lighthouse-ci-auth-setup.mjs output.
 * @param {import('puppeteer').Browser} browser
 */
module.exports = async (browser) => {
  const fs = require('node:fs');
  const path = require('node:path');

  const cookiesPath = path.join(__dirname, '.lighthouse-auth-cookies.json');
  if (!fs.existsSync(cookiesPath)) {
    throw new Error(
      `Missing ${cookiesPath}. Run: node scripts/lighthouse-ci-auth-setup.mjs (with dev stack up)`
    );
  }
  const cookies = JSON.parse(fs.readFileSync(cookiesPath, 'utf8'));
  const page = await browser.newPage();
  await page.setCookie(...cookies);
  await page.close();
};
