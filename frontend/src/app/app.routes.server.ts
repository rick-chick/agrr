import { RenderMode, PrerenderFallback, ServerRoute } from '@angular/ssr';
import { PUBLIC_PRERENDER_PATHS } from './core/seo/public-prerender-routes';
import { ENTRY_SCHEDULE_PRERENDER_CATALOG } from './core/seo/entry-schedule-prerender-catalog';

const prerenderRoutes: ServerRoute[] = PUBLIC_PRERENDER_PATHS.map((path) => ({
  path,
  renderMode: RenderMode.Prerender,
}));

export const serverRoutes: ServerRoute[] = [
  ...prerenderRoutes,
  {
    path: 'entry-schedule/crop/:cropId',
    renderMode: RenderMode.Prerender,
    fallback: PrerenderFallback.Client,
    async getPrerenderParams() {
      return ENTRY_SCHEDULE_PRERENDER_CATALOG.crops.map((crop) => ({
        cropId: String(crop.cropId),
      }));
    },
  },
  {
    path: '**',
    renderMode: RenderMode.Client,
  },
];
