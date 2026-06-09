import { inject } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { firstValueFrom } from 'rxjs';
import { applyAppLang, resolveInitialAppLang } from '../app-locale';

/**
 * Loads the initial ngx-translate locale before the root component renders.
 * Prevents layout shift from translate pipe keys appearing before JSON arrives.
 */
export async function bootstrapAppI18n(translate: TranslateService): Promise<void> {
  translate.addLangs(['ja', 'en', 'in']);
  translate.setDefaultLang('ja');
  const lang = resolveInitialAppLang();
  applyAppLang(translate, lang);
  await firstValueFrom(translate.use(lang));
}

export function provideInitialI18nBootstrap() {
  return () => {
    const translate = inject(TranslateService);
    return bootstrapAppI18n(translate);
  };
}
