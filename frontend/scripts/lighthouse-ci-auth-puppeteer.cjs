/**
 * LHCI puppeteerScript: inject dev mock-login session before each authenticated URL audit.
 *
 * Requires ng serve (proxy → strangler :3000) and agrr-server mock_login enabled.
 */
module.exports = async (browser, context) => {
  const page = await browser.newPage();
  const target = new URL(context.url);
  const loginUrl = `${target.origin}/auth/test/mock_login_as/developer?return_to=${encodeURIComponent(context.url)}`;
  const response = await page.goto(loginUrl, { waitUntil: 'networkidle0', timeout: 120_000 });
  if (!response || ![200, 302, 303, 307].includes(response.status())) {
    throw new Error(`mock_login failed for ${loginUrl} (status ${response?.status() ?? 'none'})`);
  }
  await page.close();
};
