import { Component, inject, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { take } from 'rxjs';
import { environment } from '../../../../environments/environment';
import { getApiBaseUrl } from '../../../core/api-base-url';
import { AuthService } from '../../../services/auth.service';
import {
  buildMockLoginUrl,
  buildOAuthLoginUrl,
  DEV_MOCK_LOGIN_USERS,
  type DevMockLoginUser
} from './login-auth-urls';

type RailsLocale = 'ja' | 'us' | 'in';
const RAILS_LOCALES: RailsLocale[] = ['ja', 'us', 'in'];

const DEV_MOCK_LOGIN_I18N: Record<DevMockLoginUser, string> = {
  developer: 'auth.login.dev_login_as_developer',
  farmer: 'auth.login.dev_login_as_farmer',
  researcher: 'auth.login.dev_login_as_researcher'
};

const DEV_MOCK_LOGIN_CSS: Record<DevMockLoginUser, string> = {
  developer: 'mock-btn-developer',
  farmer: 'mock-btn-farmer',
  researcher: 'mock-btn-researcher'
};

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [TranslateModule],
  template: `
    <section class="login">
      <h1>{{ 'auth.login.title' | translate }}</h1>
      <p>{{ 'auth.login.subtitle' | translate }}</p>
      <a class="login-button" [href]="loginUrl">{{ 'auth.login.google_button' | translate }}</a>

      @if (showDevMockLogin) {
        <div class="dev-login-section">
          <h2 class="dev-login-title">{{ 'auth.login.dev_login_title' | translate }}</h2>
          <div class="dev-login-buttons">
            @for (user of devMockLoginUsers; track user) {
              <a [class]="'mock-btn ' + mockLoginBtnClass(user)" [href]="mockLoginUrl(user)">
                {{ devMockLoginLabelKey(user) | translate }}
              </a>
            }
          </div>
          <p class="dev-note">{{ 'auth.login.dev_login_note' | translate }}</p>
        </div>
      }
    </section>
  `,
  styleUrls: ['./login.component.css']
})
export class LoginComponent implements OnInit {
  private readonly authService = inject(AuthService);
  private readonly router = inject(Router);

  protected readonly showDevMockLogin = environment.enableDevMockLogin;
  protected readonly devMockLoginUsers = DEV_MOCK_LOGIN_USERS;
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

  protected mockLoginUrl(user: DevMockLoginUser): string {
    const apiBase = getApiBaseUrl() || window.location.origin;
    return buildMockLoginUrl(apiBase, user, window.location);
  }

  protected devMockLoginLabelKey(user: DevMockLoginUser): string {
    return DEV_MOCK_LOGIN_I18N[user];
  }

  protected mockLoginBtnClass(user: DevMockLoginUser): string {
    return DEV_MOCK_LOGIN_CSS[user];
  }

  private buildLoginUrl(): string {
    const apiBase = getApiBaseUrl() || window.location.origin;
    const locale = this.getRailsLocale();
    return buildOAuthLoginUrl(apiBase, locale, window.location);
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
