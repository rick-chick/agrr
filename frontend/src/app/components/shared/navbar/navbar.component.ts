import { Component, EventEmitter, Input, Output } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { CurrentUser } from '../../../services/api.service';
import { getApiBaseUrl } from '../../../core/api-base-url';

@Component({
  selector: 'app-navbar',
  standalone: true,
  imports: [RouterLink, TranslateModule],
  template: `
    <nav class="app-nav">
      <div class="brand">AGRR</div>
      <div class="nav-links">
        <a class="nav-link" routerLink="/farms">{{ 'nav.farms' | translate }}</a>
        <a class="nav-link" routerLink="/crops">{{ 'nav.crops' | translate }}</a>
        <a class="nav-link" routerLink="/plans">{{ 'nav.plans' | translate }}</a>
        <a class="nav-link" routerLink="/public-plans/new">Public</a>
        <a class="nav-link" routerLink="/weather">{{ 'nav.weather' | translate }}</a>
        <a class="nav-link" routerLink="/api-keys">{{ 'nav.apiKey' | translate }}</a>
      </div>
      <div class="auth">
        @if (loading) {
          <span class="status">{{ 'status.checking' | translate }}</span>
        } @else if (user) {
          <span class="user-name">{{ user.name ?? 'User' }}</span>
          <button class="logout-button" type="button" (click)="logout.emit()">
            {{ 'nav.logout' | translate }}
          </button>
        } @else {
          <a class="login-link" [href]="loginUrl">{{ 'nav.login' | translate }}</a>
        }
      </div>
    </nav>
  `,
  styleUrl: './navbar.component.css'
})
export class NavbarComponent {
  @Input() user: CurrentUser | null = null;
  @Input() loading = false;
  @Input() apiBaseUrl = '';
  @Output() logout = new EventEmitter<void>();

  get loginUrl(): string {
    const base = this.apiBaseUrl || getApiBaseUrl() || window.location.origin;
    const returnTo = encodeURIComponent(window.location.href || window.location.origin + '/');
    return `${base}/auth/login?return_to=${returnTo}`;
  }
}
