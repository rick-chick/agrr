import { InjectionToken } from '@angular/core';

export interface CaptchaWidgetCallbacks {
  onToken: (token: string) => void;
  onExpired: () => void;
  onUnavailable: () => void;
}

export interface CaptchaWidgetPort {
  render(host: HTMLElement, callbacks: CaptchaWidgetCallbacks): void;
  reset(): void;
  remove(): void;
  isConfigured(): boolean;
}

export const CAPTCHA_WIDGET_PORT = new InjectionToken<CaptchaWidgetPort>('CAPTCHA_WIDGET_PORT');
