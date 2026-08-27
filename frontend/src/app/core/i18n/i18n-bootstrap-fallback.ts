import type { TranslationObject } from '@ngx-translate/core';
import type { AppLang } from '../app-locale';

/** Minimal translations so the shell can render when locale JSON fails to load. */
export const I18N_BOOTSTRAP_FALLBACK: Record<AppLang, TranslationObject> = {
  ja: {
    i18n: {
      bootstrap: {
        load_failed: '翻訳を読み込めませんでした',
        retry: '再試行'
      }
    },
    a11y: {
      skip_to_main: 'メインコンテンツへ'
    }
  },
  en: {
    i18n: {
      bootstrap: {
        load_failed: 'Could not load translations',
        retry: 'Retry'
      }
    },
    a11y: {
      skip_to_main: 'Skip to main content'
    }
  },
  in: {
    i18n: {
      bootstrap: {
        load_failed: 'अनुवाद लोड नहीं हो सके',
        retry: 'पुनः प्रयास करें'
      }
    },
    a11y: {
      skip_to_main: 'मुख्य सामग्री पर जाएँ'
    }
  }
};

export const I18N_BOOTSTRAP_FALLBACK_KEYS = [
  'i18n.bootstrap.load_failed',
  'i18n.bootstrap.retry'
] as const;

export function activateFallbackAppLang(translate: { currentLang: string }, lang: AppLang): void {
  translate.currentLang = lang;
}
