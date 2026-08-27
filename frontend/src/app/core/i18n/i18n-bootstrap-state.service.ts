import { Injectable, signal } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { firstValueFrom } from 'rxjs';
import { applyAppLang, documentHtmlLang, type AppLang } from '../app-locale';
import { activateFallbackAppLang, I18N_BOOTSTRAP_FALLBACK } from './i18n-bootstrap-fallback';

@Injectable({ providedIn: 'root' })
export class I18nBootstrapStateService {
  readonly loadFailed = signal(false);
  readonly failedLang = signal<AppLang | null>(null);
  readonly retryInProgress = signal(false);

  markFailed(lang: AppLang): void {
    this.loadFailed.set(true);
    this.failedLang.set(lang);
  }

  markSuccess(): void {
    this.loadFailed.set(false);
    this.failedLang.set(null);
    this.retryInProgress.set(false);
  }

  applyFallbackTranslations(translate: TranslateService, lang: AppLang): void {
    translate.setTranslation(lang, I18N_BOOTSTRAP_FALLBACK[lang], true);
    activateFallbackAppLang(translate, lang);
    if (typeof document !== 'undefined') {
      document.documentElement.lang = documentHtmlLang(lang);
    }
  }

  async retry(translate: TranslateService): Promise<void> {
    const lang = this.failedLang();
    if (!lang || this.retryInProgress()) {
      return;
    }

    this.retryInProgress.set(true);
    applyAppLang(translate, lang, { persist: false });
    try {
      await firstValueFrom(translate.use(lang));
      this.markSuccess();
    } catch {
      this.applyFallbackTranslations(translate, lang);
      this.markFailed(lang);
    } finally {
      this.retryInProgress.set(false);
    }
  }
}
