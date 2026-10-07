import { Injectable, PLATFORM_ID, inject } from '@angular/core';
import { isPlatformBrowser } from '@angular/common';
import {
  CaptchaWidgetCallbacks,
  CaptchaWidgetPort
} from '../../usecase/contact/captcha-widget.port';
import { getTurnstileSiteKey } from '../../core/turnstile-runtime-config';

const TURNSTILE_SCRIPT_URL =
  'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';

type TurnstileApi = {
  render: (
    container: HTMLElement,
    options: Record<string, unknown>
  ) => string;
  reset: (widgetId?: string) => void;
  remove: (widgetId?: string) => void;
};

declare global {
  interface Window {
    turnstile?: TurnstileApi;
  }
}

@Injectable()
export class TurnstileWidgetAdapter implements CaptchaWidgetPort {
  private readonly platformId = inject(PLATFORM_ID);
  private widgetId: string | null = null;
  private loadPromise: Promise<void> | null = null;

  isConfigured(): boolean {
    return getTurnstileSiteKey().length > 0;
  }

  render(host: HTMLElement, language: string, callbacks: CaptchaWidgetCallbacks): void {
    if (!isPlatformBrowser(this.platformId)) {
      callbacks.onUnavailable();
      return;
    }
    const siteKey = getTurnstileSiteKey();
    if (!siteKey) {
      callbacks.onUnavailable();
      return;
    }
    this.loadScript()
      .then(() => {
        const turnstile = window.turnstile;
        if (!turnstile) {
          callbacks.onUnavailable();
          return;
        }
        this.remove();
        this.widgetId = turnstile.render(host, {
          sitekey: siteKey,
          action: 'contact',
          language,
          theme: 'auto',
          size: 'flexible',
          'response-field': false,
          callback: (token: string) => callbacks.onToken(token),
          'error-callback': () => callbacks.onUnavailable(),
          'expired-callback': () => callbacks.onExpired(),
          'timeout-callback': () => callbacks.onExpired()
        });
      })
      .catch(() => callbacks.onUnavailable());
  }

  reset(): void {
    if (!isPlatformBrowser(this.platformId) || !window.turnstile || !this.widgetId) {
      return;
    }
    window.turnstile.reset(this.widgetId);
  }

  remove(): void {
    if (!isPlatformBrowser(this.platformId) || !window.turnstile || !this.widgetId) {
      this.widgetId = null;
      return;
    }
    window.turnstile.remove(this.widgetId);
    this.widgetId = null;
  }

  private loadScript(): Promise<void> {
    if (!isPlatformBrowser(this.platformId)) {
      return Promise.reject(new Error('not browser'));
    }
    if (window.turnstile) {
      return Promise.resolve();
    }
    if (this.loadPromise) {
      return this.loadPromise;
    }
    this.loadPromise = new Promise((resolve, reject) => {
      const existing = document.querySelector(`script[src^="${TURNSTILE_SCRIPT_URL}"]`);
      if (existing) {
        existing.addEventListener('load', () => resolve(), { once: true });
        existing.addEventListener('error', () => reject(new Error('script error')), {
          once: true
        });
        return;
      }
      const script = document.createElement('script');
      script.src = TURNSTILE_SCRIPT_URL;
      script.async = true;
      script.defer = true;
      script.onload = () => resolve();
      script.onerror = () => reject(new Error('script error'));
      document.head.appendChild(script);
    });
    return this.loadPromise;
  }
}
