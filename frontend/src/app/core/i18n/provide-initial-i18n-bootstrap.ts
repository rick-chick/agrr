import { isPlatformBrowser } from '@angular/common';
import { inject, PLATFORM_ID } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { I18N_PRERENDER_DEFAULT_LANG } from './i18n-bootstrap.constants';
import { bootstrapAppI18n } from './initial-i18n-bootstrap';
import { I18nBootstrapStateService } from './i18n-bootstrap-state.service';

export function provideInitialI18nBootstrap() {
  return () => {
    const translate = inject(TranslateService);
    const platformId = inject(PLATFORM_ID);
    const state = inject(I18nBootstrapStateService);
    const lang = isPlatformBrowser(platformId) ? undefined : I18N_PRERENDER_DEFAULT_LANG;
    return bootstrapAppI18n(translate, { lang, state });
  };
}
