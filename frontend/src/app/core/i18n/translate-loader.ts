import { HttpClient } from '@angular/common/http';
import { TranslateLoader } from '@ngx-translate/core';
import { Observable } from 'rxjs';

/**
 * Creates a TranslateLoader factory function that loads translation files
 * from /assets/i18n/{lang}.json, optionally handling STATIC_PATH_PREFIX.
 *
 * @param http - HttpClient instance for loading translation files
 * @returns TranslateLoader implementation
 */
export function createTranslateLoader(http: HttpClient): TranslateLoader {
  const STATIC_PATH_PREFIX = (globalThis as any).STATIC_PATH_PREFIX || '';
  
  return {
    getTranslation(lang: string): Observable<any> {
      const base = STATIC_PATH_PREFIX ? `/${STATIC_PATH_PREFIX}` : '';
      return http.get(`${base}/assets/i18n/${lang}.json`);
    }
  };
}
