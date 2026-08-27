import { TranslateService } from '@ngx-translate/core';
import { catchError, firstValueFrom, of } from 'rxjs';
import { applyAppLang, resolveInitialAppLang, type AppLang } from '../app-locale';
import { getI18nBootstrapFallback } from './i18n-bootstrap-fallback';
import type { I18nBootstrapStatePort } from './i18n-bootstrap-state.port';

type BootstrapAppI18nOptions = {
  lang?: AppLang;
  state?: I18nBootstrapStatePort;
};

function normalizeBootstrapOptions(
  langOrOptions?: AppLang | BootstrapAppI18nOptions
): BootstrapAppI18nOptions {
  if (langOrOptions === undefined) {
    return {};
  }
  if (typeof langOrOptions === 'string') {
    return { lang: langOrOptions };
  }
  return langOrOptions;
}

/**
 * Loads the initial ngx-translate locale before the root component renders.
 * Prevents layout shift from translate pipe keys appearing before JSON arrives.
 * On load failure, applies a minimal fallback dictionary so the shell can still boot.
 */
export async function bootstrapAppI18n(
  translate: TranslateService,
  langOrOptions?: AppLang | BootstrapAppI18nOptions
): Promise<void> {
  const { lang, state } = normalizeBootstrapOptions(langOrOptions);

  translate.addLangs(['ja', 'en', 'in']);
  translate.setDefaultLang('ja');
  const resolved = lang ?? resolveInitialAppLang();
  applyAppLang(translate, resolved);

  let loadFailed = false;
  await firstValueFrom(
    translate.use(resolved).pipe(
      catchError(() => {
        loadFailed = true;
        translate.setTranslation(resolved, getI18nBootstrapFallback(resolved), true);
        return of(getI18nBootstrapFallback(resolved));
      })
    )
  );

  if (loadFailed) {
    state?.markFailed();
  } else {
    state?.markSuccess();
  }
}
