import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const config = JSON.parse(readFileSync(join(__dirname, 'lighthouse-ci-routes.json'), 'utf8'));

export const LIGHTHOUSE_CI_ROUTES = config.routes;
export const LIGHTHOUSE_CI_AUTH_ROUTES = config.authRoutes ?? [];
export const LIGHTHOUSE_CI_THRESHOLDS = config.thresholds;

/** @returns {boolean} */
export function hasMobilePresetRoute() {
  const all = [...LIGHTHOUSE_CI_ROUTES, ...LIGHTHOUSE_CI_AUTH_ROUTES];
  return all.some((route) => route.preset === 'mobile');
}
