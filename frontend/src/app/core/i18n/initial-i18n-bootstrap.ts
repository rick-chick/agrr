import { isPlatformBrowser } from '@angular/common';
import { inject, PLATFORM_ID } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { firstValueFrom } from 'rxjs';
import { applyAppLang, documentHtmlLang, resolveInitialAppLang, type AppLang } from '../app-locale';
import { activateFallbackAppLang, I18N_BOOTSTRAP_FALLBACK } from './i18n-bootstrap-fallback';
import { I18nBootstrapStateService } from './i18n-bootstrap-state.service';

const PRERENDER_DEFAULT_LANG: AppLang = 'ja';

/**
 * Loads the initial ngx-translate locale before the root component renders.
 * Prevents layout shift from translate pipe keys appearing before JSON arrives.
 * On load failure, applies a minimal fallback dictionary so the shell can still start.
 */
export async function bootstrapAppI18n(
  translate: TranslateService,
  lang?: AppLang,
  state?: I18nBootstrapStateService
): Promise<void> {
  translate.addLangs(['ja', 'en', 'in']);
  translate.setDefaultLang('ja');
  const resolved = lang ?? resolveInitialAppLang();
  applyAppLang(translate, resolved);

  try {
    await firstValueFrom(translate.use(resolved));
    state?.markSuccess();
  } catch {
    translate.setTranslation(resolved, I18N_BOOTSTRAP_FALLBACK[resolved], true);
    activateFallbackAppLang(translate, resolved);
    if (typeof document !== 'undefined') {
      document.documentElement.lang = documentHtmlLang(resolved);
    }
    state?.markFailed(resolved);
  }
}

export function provideInitialI18nBootstrap() {
  return () => {
    const translate = inject(TranslateService);
    const platformId = inject(PLATFORM_ID);
    const state = inject(I18nBootstrapStateService);
    const lang = isPlatformBrowser(platformId) ? undefined : PRERENDER_DEFAULT_LANG;
    return bootstrapAppI18n(translate, lang, state);
  };
}
