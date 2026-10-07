import { InjectionToken } from '@angular/core';

export interface CaptchaWidgetCallbacks {
  onToken(token: string): void;
  onExpired(): void;
  onUnavailable(): void;
}

export interface CaptchaWidgetPort {
  isConfigured(): boolean;
  render(host: HTMLElement, language: string, callbacks: CaptchaWidgetCallbacks): void;
  reset(): void;
  remove(): void;
}

export const CAPTCHA_WIDGET_PORT = new InjectionToken<CaptchaWidgetPort>('CAPTCHA_WIDGET_PORT');
