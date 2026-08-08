import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const config = JSON.parse(readFileSync(join(__dirname, 'lighthouse-ci-routes.json'), 'utf8'));

export const LIGHTHOUSE_CI_PUBLIC_ROUTES = config.publicRoutes;
export const LIGHTHOUSE_CI_MOBILE_PUBLIC_ROUTE = config.mobilePublicRoute;
export const LIGHTHOUSE_CI_AUTH_ROUTE_TEMPLATES = config.authenticatedRoutes;
export const LIGHTHOUSE_CI_THRESHOLDS = config.thresholds;

/** @deprecated use LIGHTHOUSE_CI_PUBLIC_ROUTES */
export const LIGHTHOUSE_CI_ROUTES = config.publicRoutes;
