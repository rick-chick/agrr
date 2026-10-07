import { environment } from '../../environments/environment';

declare global {
  interface Window {
    TURNSTILE_SITE_KEY?: string;
  }
}

export function getTurnstileSiteKey(): string {
  const fromWindow =
    typeof window !== 'undefined' ? window.TURNSTILE_SITE_KEY?.trim() : '';
  if (fromWindow) {
    return fromWindow;
  }
  return (environment.turnstileSiteKey ?? '').trim();
}
