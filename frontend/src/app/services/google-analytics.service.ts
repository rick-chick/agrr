import { Injectable } from '@angular/core';
import { environment } from '../../environments/environment';

export type ConsentStatus = 'granted' | 'denied';

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

  trackPageView(path: string): void {
    if (!this.isEnabled) {
      return;
    }

    this.safeInvoke('config', this.measurementId, {
      page_path: path,
      anonymize_ip: true,
      cookie_flags: 'SameSite=None;Secure'
    });
  }

  trackEvent(eventName: string, params: Record<string, unknown> = {}): void {
    if (!this.isEnabled) {
      return;
    }

    this.safeInvoke('event', eventName, params);
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
    this.safeInvoke('consent', 'default', this.defaultConsent);
    this.safeInvoke('config', this.measurementId, {
      anonymize_ip: true,
      cookie_flags: 'SameSite=None;Secure'
    });
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
      window.gtag = (...args: unknown[]) => {
        window.dataLayer?.push(args);
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
