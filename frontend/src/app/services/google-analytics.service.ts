import { Injectable } from '@angular/core';

export type ConsentStatus = 'granted' | 'denied';

@Injectable({ providedIn: 'root' })
export class GoogleAnalyticsService {
  private readonly measurementId = 'G-WNLSL6W4ZT';
  private readonly storageKey = 'cookieConsentStatus';

  applyStoredConsent(): void {
    const stored = this.getStoredConsent();
    if (stored) {
      this.updateConsentPayload(stored === 'granted');
    }
  }

  updateConsent(granted: boolean): void {
    this.setStoredConsent(granted ? 'granted' : 'denied');
    this.updateConsentPayload(granted);
  }

  trackPageView(path: string): void {
    this.safeInvoke('config', this.measurementId, {
      page_path: path,
      anonymize_ip: true,
      cookie_flags: 'SameSite=None;Secure'
    });
  }

  trackEvent(eventName: string, params: Record<string, unknown> = {}): void {
    this.safeInvoke('event', eventName, params);
  }

  getStoredConsent(): ConsentStatus | null {
    try {
      return (window.localStorage?.getItem(this.storageKey) as ConsentStatus | null) ?? null;
    } catch {
      return null;
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

  private safeInvoke(...args: unknown[]): void {
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
