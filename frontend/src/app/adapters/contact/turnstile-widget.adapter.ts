import { Injectable, PLATFORM_ID, inject } from '@angular/core';
import { isPlatformBrowser } from '@angular/common';
import { documentHtmlLang } from '../../core/app-locale';
import { getTurnstileSiteKey } from '../../core/turnstile-runtime-config';
import {
  CaptchaWidgetCallbacks,
  CaptchaWidgetPort
} from '../../usecase/contact/captcha-widget.port';
import { TranslateService } from '@ngx-translate/core';

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
  private readonly translate = inject(TranslateService);

  private widgetId: string | null = null;
  private callbacks: CaptchaWidgetCallbacks | null = null;
  private scriptLoading: Promise<void> | null = null;

  isConfigured(): boolean {
    return getTurnstileSiteKey().length > 0;
  }

  render(host: HTMLElement, callbacks: CaptchaWidgetCallbacks): void {
    this.callbacks = callbacks;
    if (!isPlatformBrowser(this.platformId)) {
      callbacks.onUnavailable();
      return;
    }
    if (!this.isConfigured()) {
      callbacks.onUnavailable();
      return;
    }
    this.loadScript()
      .then(() => this.renderWidget(host))
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

  private renderWidget(host: HTMLElement): void {
    const turnstile = window.turnstile;
    if (!turnstile) {
      this.callbacks?.onUnavailable();
      return;
    }
    if (this.widgetId) {
      turnstile.remove(this.widgetId);
      this.widgetId = null;
    }
    const lang = documentHtmlLang(this.translate.currentLang as 'ja' | 'en' | 'in');
    this.widgetId = turnstile.render(host, {
      sitekey: getTurnstileSiteKey(),
      action: 'contact',
      theme: 'auto',
      size: 'flexible',
      language: lang,
      'response-field': false,
      callback: (token: string) => this.callbacks?.onToken(token),
      'error-callback': () => this.callbacks?.onUnavailable(),
      'expired-callback': () => this.callbacks?.onExpired(),
      'timeout-callback': () => this.callbacks?.onExpired()
    });
  }

  private loadScript(): Promise<void> {
    if (!isPlatformBrowser(this.platformId)) {
      return Promise.reject(new Error('not browser'));
    }
    if (window.turnstile) {
      return Promise.resolve();
    }
    if (this.scriptLoading) {
      return this.scriptLoading;
    }
    this.scriptLoading = new Promise<void>((resolve, reject) => {
      const existing = document.querySelector<HTMLScriptElement>(
        'script[data-turnstile="true"]'
      );
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
      script.setAttribute('data-turnstile', 'true');
      script.onload = () => {
        if (window.turnstile) {
          resolve();
        }
      };
      script.onerror = () => reject(new Error('turnstile script failed'));
      document.head.appendChild(script);
    });
    return this.scriptLoading;
  }
}
