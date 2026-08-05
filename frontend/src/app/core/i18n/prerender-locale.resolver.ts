import { inject } from '@angular/core';
import { ResolveFn } from '@angular/router';
import { TranslateService } from '@ngx-translate/core';
import type { AppLang } from '../app-locale';
import { bootstrapAppI18n } from './initial-i18n-bootstrap';

/** Forces ngx-translate locale before prerender/SSR renders child routes. */
export function createPrerenderLocaleResolver(lang: AppLang): ResolveFn<unknown> {
  return () => {
    const translate = inject(TranslateService);
    return bootstrapAppI18n(translate, lang);
  };
}

export const prerenderEnLocaleResolver = createPrerenderLocaleResolver('en');
