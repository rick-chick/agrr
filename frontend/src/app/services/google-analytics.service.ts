import { Injectable } from '@angular/core';
import { COOKIE_CONTROL_UI_DISABLED } from '../core/cookie-consent-policy';
import { getGoogleAdsConversionId } from '../core/google-ads-runtime-config';
import { environment } from '../../environments/environment';

export type ConsentStatus = 'granted' | 'denied';

/** Google Ads サイトコンバージョン `gtag('event','conversion',…)` に渡す引数の一部 */
export interface GoogleAdsConversionPayload {
  send_to: string;
  value?: number;
  currency?: string;
  transaction_id?: string;
}

@Injectable({ providedIn: 'root' })
export class GoogleAnalyticsService {
  private readonly measurementId = environment.googleAnalyticsMeasurementId;
  private readonly storageKey = 'cookieConsentStatus';
  private readonly isEnabled = environment.enableGoogleAnalytics;
  private readonly defaultConsent = {
    ad_storage: 'denied',
    ad_user_data: 'denied',
    ad_personalization: 'denied',
    analytics_storage: 'denied',
    functionality_storage: 'granted',
    security_storage: 'granted',
    wait_for_update: 500
  };
  private initialized = false;

  constructor() {
    if (this.isEnabled) {
      this.initialize();
    }
  }

  applyStoredConsent(): void {
    if (!this.isEnabled) {
      return;
    }

    const stored = this.getStoredConsent();
    if (stored) {
      this.updateConsentPayload(stored === 'granted');
    }
  }

  updateConsent(granted: boolean): void {
    if (!this.isEnabled) {
      return;
    }

    this.setStoredConsent(granted ? 'granted' : 'denied');
    this.updateConsentPayload(granted);
  }

  /**
   * SPA 遷移では `gtag('config', …)` を繰り返すと `_ga_*` の expires が毎回上書きされ、
   * ブラウザが警告する。GA4 では仮想ページビューに `page_view` イベントを使う。
   */
  trackPageView(path: string): void {
    if (!this.isEnabled) {
      return;
    }

    this.safeInvoke('event', 'page_view', {
      page_path: path,
      anonymize_ip: true
    });
  }

  trackEvent(eventName: string, params: Record<string, unknown> = {}): void {
    if (!this.isEnabled) {
      return;
    }

    this.safeInvoke('event', eventName, params);
  }

  /**
   * Google 広告のサイトコンバージョン（広告側で作成したコンバージョンアクションの send_to）。
   * クッキー同意で ad_storage が拒否されている場合でも gtag は呼ぶが送信はプラットフォーム側でブロックされる。
   */
  trackAdsConversion(payload: GoogleAdsConversionPayload): void {
    if (!this.isEnabled) {
      return;
    }
    const sendTo = payload.send_to?.trim();
    if (!sendTo) {
      return;
    }

    const { send_to: _drop, ...rest } = payload;
    this.safeInvoke('event', 'conversion', {
      send_to: sendTo,
      ...rest
    });
  }

  getStoredConsent(): ConsentStatus | null {
    try {
      return (window.localStorage?.getItem(this.storageKey) as ConsentStatus | null) ?? null;
    } catch {
      return null;
    }
  }

  private initialize(): void {
    if (this.initialized) {
      return;
    }

    this.initialized = true;
    this.ensureGtagFunction();
    this.insertScript();
    this.safeInvoke('js', new Date());
    // When the UI auto-grants consent, default-deny analytics here races the first NavigationEnd
    // and can suppress g/collect until a second navigation. Align defaults with cookie-consent-banner.
    const consentDefault = COOKIE_CONTROL_UI_DISABLED
      ? {
          ...this.defaultConsent,
          analytics_storage: 'granted' as const
        }
      : this.defaultConsent;
    this.safeInvoke('consent', 'default', consentDefault);
    this.safeInvoke('config', this.measurementId, {
      anonymize_ip: true,
      cookie_flags: 'SameSite=None;Secure',
      send_page_view: false
    });

    const googleAdsId = getGoogleAdsConversionId();
    if (googleAdsId) {
      this.safeInvoke('config', googleAdsId, {
        anonymize_ip: true,
        cookie_flags: 'SameSite=None;Secure',
        send_page_view: false
      });
    }
  }

  private updateConsentPayload(granted: boolean): void {
    const consentPayload = {
      ad_storage: granted ? 'granted' : 'denied',
      ad_user_data: granted ? 'granted' : 'denied',
      ad_personalization: granted ? 'granted' : 'denied',
      analytics_storage: granted ? 'granted' : 'denied',
      functionality_storage: 'granted',
      security_storage: 'granted'
    };

    this.safeInvoke('consent', 'update', consentPayload);

    if (granted && typeof window.loadAdSense === 'function') {
      window.loadAdSense();
    }
  }

  private setStoredConsent(value: ConsentStatus): void {
    try {
      window.localStorage?.setItem(this.storageKey, value);
    } catch {
      // ignore storage failures
    }
  }

  private ensureGtagFunction(): void {
    if (typeof window === 'undefined') {
      return;
    }

    window.dataLayer = window.dataLayer || [];

    if (typeof window.gtag !== 'function') {
      window.gtag = function gtag() {
        window.dataLayer!.push(arguments);
      };
    }
  }

  private insertScript(): void {
    if (typeof document === 'undefined' || !document.head) {
      return;
    }

    if (document.head.querySelector(`script[data-ga="${this.measurementId}"]`)) {
      return;
    }

    const script = document.createElement('script');
    script.async = true;
    script.src = `https://www.googletagmanager.com/gtag/js?id=${this.measurementId}`;
    script.setAttribute('data-ga', this.measurementId);
    document.head.appendChild(script);
  }

  private safeInvoke(...args: unknown[]): void {
    if (!this.isEnabled || typeof window === 'undefined') {
      return;
    }

    if (typeof window.gtag === 'function') {
      window.gtag(...args);
      return;
    }

    window.dataLayer = window.dataLayer || [];
    window.dataLayer.push(args);
  }
}

declare global {
  interface Window {
    gtag?: (...args: unknown[]) => void;
    dataLayer?: unknown[];
    loadAdSense?: () => void;
  }
}
