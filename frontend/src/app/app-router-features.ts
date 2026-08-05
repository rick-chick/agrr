import { withInMemoryScrolling } from '@angular/router';

export const APP_ROUTER_SCROLL_OPTIONS = {
  scrollPositionRestoration: 'enabled',
  anchorScrolling: 'enabled'
} as const;

/** Router features shared by `app.config.ts` (testable scroll restoration contract). */
export const appRouterFeatures = [withInMemoryScrolling(APP_ROUTER_SCROLL_OPTIONS)];
