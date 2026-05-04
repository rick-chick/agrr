import { Component, inject, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { take } from 'rxjs';
import { getApiBaseUrl } from '../../../core/api-base-url';
import { AuthService } from '../../../services/auth.service';

type RailsLocale = 'ja' | 'us' | 'in';
const RAILS_LOCALES: RailsLocale[] = ['ja', 'us', 'in'];

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [TranslateModule],
  template: `
    <section class="login">
      <h1>{{ 'auth.login.title' | translate }}</h1>
      <p>{{ 'auth.login.description' | translate }}</p>
      <a class="login-button" [href]="loginUrl">{{ 'auth.login.google_button' | translate }}</a>
    </section>
  `,
  styleUrls: ['./login.component.css']
})
export class LoginComponent implements OnInit {
  private readonly authService = inject(AuthService);
  private readonly router = inject(Router);

  protected readonly loginUrl = this.buildLoginUrl();

  ngOnInit(): void {
    this.authService
      .loadCurrentUser()
      .pipe(take(1))
      .subscribe((user) => {
        if (user) {
          void this.router.navigateByUrl('/', { replaceUrl: true });
        }
      });
  }

  private buildLoginUrl(): string {
    const apiBase = getApiBaseUrl() || window.location.origin;
    const locale = this.getRailsLocale();
    const returnTo = encodeURIComponent(this.oauthReturnToUrl());
    return `${apiBase}/${locale}/auth/login?return_to=${returnTo}`;
  }

  /** OAuth 完了後の戻り先。ログインページから開始した場合はループを避けてホームへ。 */
  private oauthReturnToUrl(): string {
    let path = window.location.pathname;
    if (path.length > 1 && path.endsWith('/')) {
      path = path.slice(0, -1);
    }
    const onLoginPath = path === '/login' || path.endsWith('/login');
    if (onLoginPath) {
      return `${window.location.origin}/`;
    }
    return window.location.href || `${window.location.origin}/`;
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
