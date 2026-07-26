import { isPlatformBrowser } from '@angular/common';
import { inject, PLATFORM_ID } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { firstValueFrom } from 'rxjs';
import { applyAppLang, resolveInitialAppLang, type AppLang } from '../app-locale';

const PRERENDER_DEFAULT_LANG: AppLang = 'ja';

/**
 * Loads the initial ngx-translate locale before the root component renders.
 * Prevents layout shift from translate pipe keys appearing before JSON arrives.
 */
export async function bootstrapAppI18n(
  translate: TranslateService,
  lang?: AppLang
): Promise<void> {
  translate.addLangs(['ja', 'en', 'in']);
  translate.setDefaultLang('ja');
  const resolved = lang ?? resolveInitialAppLang();
  applyAppLang(translate, resolved);
  await firstValueFrom(translate.use(resolved));
}

export function provideInitialI18nBootstrap() {
  return () => {
    const translate = inject(TranslateService);
    const platformId = inject(PLATFORM_ID);
    const lang = isPlatformBrowser(platformId) ? undefined : PRERENDER_DEFAULT_LANG;
    return bootstrapAppI18n(translate, lang);
  };
}
