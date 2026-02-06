import { HttpClient } from '@angular/common/http';
import { TranslateLoader } from '@ngx-translate/core';
import { Observable } from 'rxjs';

const STATIC_PATH_PREFIX = (globalThis as any).STATIC_PATH_PREFIX || '';

export class SimpleTranslateLoader implements TranslateLoader {
  constructor(private http: HttpClient) {}

  getTranslation(lang: string): Observable<any> {
    const base = STATIC_PATH_PREFIX ? `/${STATIC_PATH_PREFIX}` : '';
    return this.http.get(`${base}/assets/i18n/${lang}.json`);
  }
}
