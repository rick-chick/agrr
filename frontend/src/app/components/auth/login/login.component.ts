import { Component } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { getApiBaseUrl } from '../../../core/api-base-url';

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
  styleUrl: './login.component.css'
})
export class LoginComponent {
  protected readonly loginUrl = this.buildLoginUrl();

  private buildLoginUrl(): string {
    const apiBase = getApiBaseUrl() || window.location.origin;
    const returnTo = encodeURIComponent(window.location.href || window.location.origin + '/');
    return `${apiBase}/auth/login?return_to=${returnTo}`;
  }
}
