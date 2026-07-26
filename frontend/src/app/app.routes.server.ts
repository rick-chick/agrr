import { RenderMode, ServerRoute } from '@angular/ssr';
import { PUBLIC_PRERENDER_PATHS } from './core/seo/public-prerender-routes';

const prerenderRoutes: ServerRoute[] = PUBLIC_PRERENDER_PATHS.map((path) => ({
  path,
  renderMode: RenderMode.Prerender,
}));

export const serverRoutes: ServerRoute[] = [
  ...prerenderRoutes,
  {
    path: '**',
    renderMode: RenderMode.Client,
  },
];
