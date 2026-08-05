import { RenderMode, ServerRoute } from '@angular/ssr';
import {
  PUBLIC_PRERENDER_EN_PATHS,
  PUBLIC_PRERENDER_PATHS,
} from './core/seo/public-prerender-routes';

const prerenderPaths = [...PUBLIC_PRERENDER_PATHS, ...PUBLIC_PRERENDER_EN_PATHS];

const prerenderRoutes: ServerRoute[] = prerenderPaths.map((path) => ({
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
