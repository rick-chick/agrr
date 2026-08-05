import { HttpClient } from '@angular/common/http';
import { TranslateLoader } from '@ngx-translate/core';
import { Observable } from 'rxjs';
import { resolveStaticPathPrefix } from './resolve-static-path-prefix';

/**
 * Creates a TranslateLoader factory function that loads translation files
 * from /assets/i18n/{lang}.json, optionally handling STATIC_PATH_PREFIX.
 *
 * @param http - HttpClient instance for loading translation files
 * @returns TranslateLoader implementation
 */
export function createTranslateLoader(http: HttpClient): TranslateLoader {
  return {
    getTranslation(lang: string): Observable<any> {
      const staticPathPrefix = resolveStaticPathPrefix();
      const base = staticPathPrefix ? `/${staticPathPrefix}` : '';
      return http.get(`${base}/assets/i18n/${lang}.json`);
    }
  };
}
