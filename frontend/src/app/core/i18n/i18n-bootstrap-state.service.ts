import { isPlatformBrowser } from '@angular/common';
import { Injectable, PLATFORM_ID, inject, signal } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { bootstrapAppI18n } from './initial-i18n-bootstrap';
import type { I18nBootstrapStatePort } from './i18n-bootstrap-state.port';

export type { I18nBootstrapStatePort } from './i18n-bootstrap-state.port';

const PRERENDER_DEFAULT_LANG = 'ja' as const;

@Injectable({ providedIn: 'root' })
export class I18nBootstrapStateService implements I18nBootstrapStatePort {
  private readonly translate = inject(TranslateService);
  private readonly platformId = inject(PLATFORM_ID);

  private readonly _loadFailed = signal(false);
  private readonly _retrying = signal(false);

  readonly loadFailed = this._loadFailed.asReadonly();
  readonly retrying = this._retrying.asReadonly();

  markFailed(): void {
    this._loadFailed.set(true);
    this._retrying.set(false);
  }

  markSuccess(): void {
    this._loadFailed.set(false);
    this._retrying.set(false);
  }

  markRetrying(): void {
    this._retrying.set(true);
  }

  async retry(): Promise<void> {
    this.markRetrying();
    const lang = isPlatformBrowser(this.platformId) ? undefined : PRERENDER_DEFAULT_LANG;
    await bootstrapAppI18n(this.translate, { lang, state: this });
  }
}
