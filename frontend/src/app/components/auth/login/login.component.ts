import { Component, inject, OnInit } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { take } from 'rxjs';
import { environment } from '../../../../environments/environment';
import { getApiBaseUrl } from '../../../core/api-base-url';
import { AuthService } from '../../../services/auth.service';
import {
  buildGoogleOAuthStartUrl,
  buildMockLoginUrl,
  DEV_MOCK_LOGIN_USERS,
  navigateTargetFromReturnTo,
  oauthLocationForLogin,
  type DevMockLoginUser
} from './login-auth-urls';

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
      <form class="google-oauth-form" method="post" [action]="googleOAuthStartUrl">
        <button type="submit" class="login-button">
          {{ 'auth.login.google_button' | translate }}
        </button>
      </form>

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
  private readonly route = inject(ActivatedRoute);

  protected readonly showDevMockLogin = environment.enableDevMockLogin;
  protected readonly devMockLoginUsers = DEV_MOCK_LOGIN_USERS;
  /** `googleOAuthStartUrl` より先に初期化すること（OAuth return_to 算出に必要） */
  protected readonly oauthLocation = this.resolveOauthLocation();
  protected readonly googleOAuthStartUrl = this.buildGoogleOAuthStartUrl();

  ngOnInit(): void {
    this.authService
      .loadCurrentUser()
      .pipe(take(1))
      .subscribe((user) => {
        if (user) {
          const target = navigateTargetFromReturnTo(
            this.route.snapshot.queryParamMap.get('return_to'),
            window.location.origin
          );
          void this.router.navigateByUrl(target ?? '/', { replaceUrl: true });
        }
      });
  }

  protected mockLoginUrl(user: DevMockLoginUser): string {
    return buildMockLoginUrl(getApiBaseUrl(), user, this.oauthLocation);
  }

  protected devMockLoginLabelKey(user: DevMockLoginUser): string {
    return DEV_MOCK_LOGIN_I18N[user];
  }

  protected mockLoginBtnClass(user: DevMockLoginUser): string {
    return DEV_MOCK_LOGIN_CSS[user];
  }

  private resolveOauthLocation() {
    const returnTo = this.route.snapshot.queryParamMap.get('return_to');
    return oauthLocationForLogin(window.location, returnTo);
  }

  private buildGoogleOAuthStartUrl(): string {
    return buildGoogleOAuthStartUrl(getApiBaseUrl(), this.oauthLocation);
  }
}
