import { Component } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { getApiBaseUrl } from '../../../core/api-base-url';

type RailsLocale = 'ja' | 'us' | 'in';
const RAILS_LOCALES: RailsLocale[] = ['ja', 'us', 'in'];

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [TranslateModule],
  template: `
    <section class="login">
      <h1>{{ 'login.title' | translate }}</h1>
      <p>{{ 'login.description' | translate }}</p>
      <a class="login-button" [href]="loginUrl">Google OAuth</a>
    </section>
  `,
  styleUrls: ['./login.component.css']
})
export class LoginComponent {
  protected readonly loginUrl = this.buildLoginUrl();

  private buildLoginUrl(): string {
    const apiBase = getApiBaseUrl() || window.location.origin;
    const locale = this.getRailsLocale();
    const returnTo = encodeURIComponent(window.location.href || window.location.origin + '/');
    return `${apiBase}/${locale}/auth/login?return_to=${returnTo}`;
  }

  private getRailsLocale(): RailsLocale {
    const cookieLocale = readLocaleFromCookie();
    if (cookieLocale) {
      return cookieLocale;
    }

    return detectBrowserLangForRails();
  }
}

function readLocaleFromCookie(): RailsLocale | null {
  if (typeof document === 'undefined' || !document.cookie) {
    return null;
  }

  const match = document.cookie
    .split(';')
    .map((segment) => segment.trim())
    .find((segment) => segment.startsWith('locale='));

  if (!match) {
    return null;
  }

  const value = match.split('=')[1];
  if (!value) {
    return null;
  }

  return RAILS_LOCALES.includes(value as RailsLocale) ? (value as RailsLocale) : null;
}

function detectBrowserLangForRails(): RailsLocale {
  if (typeof navigator === 'undefined') {
    return 'ja';
  }

  const langs: readonly string[] =
    navigator.languages?.length ? [...navigator.languages] : (navigator.language ? [navigator.language] : []);

  for (const raw of langs) {
    const code = raw.split('-')[0].toLowerCase();
    if (code === 'en') {
      return 'us';
    }
    if (code === 'hi') {
      return 'in';
    }
    if (code === 'ja') {
      return 'ja';
    }
  }

  return 'ja';
}
