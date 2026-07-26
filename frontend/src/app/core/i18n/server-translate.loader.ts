import { TranslateLoader, TranslationObject } from '@ngx-translate/core';
import { Observable, of } from 'rxjs';
import en from '../../../assets/i18n/en.json';
import inLang from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

const TRANSLATIONS: Record<string, TranslationObject> = {
  ja,
  en,
  in: inLang,
};

/** Bundles locale JSON for build-time prerender (no HTTP). */
export function createServerTranslateLoader(): TranslateLoader {
  return {
    getTranslation(lang: string): Observable<TranslationObject> {
      return of(TRANSLATIONS[lang] ?? TRANSLATIONS['ja']);
    },
  };
}
