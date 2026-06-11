import { Component, EventEmitter, Input, Output, inject } from '@angular/core';
import { RouterLink, RouterLinkActive } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { loginReturnQueryForLocation } from '../../auth/login/login-auth-urls';
import { type CurrentUser } from '../../../services/api.service';
import { NavDropdownComponent } from '../nav-dropdown/nav-dropdown.component';

/** 画面完結のドロップダウンは app-nav-dropdown に委譲。ここは認証・リンク構成だけ。 */
@Component({
  selector: 'app-navbar',
  standalone: true,
  imports: [RouterLink, RouterLinkActive, TranslateModule, NavDropdownComponent],
  template: `
    <nav class="app-nav" [attr.aria-label]="'nav.main' | translate" [attr.data-menu-open]="isMenuOpen">
      <a class="brand" routerLink="/" routerLinkActive="is-active" [routerLinkActiveOptions]="{ exact: true }">AGRR</a>
      <button
        class="menu-toggle"
        type="button"
        [attr.aria-expanded]="isMenuOpen"
        [attr.aria-label]="isMenuOpen ? ('nav.close_menu' | translate) : ('nav.open_menu' | translate)"
        (click)="toggleMenu()"
      >
        <span class="menu-toggle-icon" aria-hidden="true"></span>
      </button>
      <ul class="nav-links" role="list">
        @if (user) {
          <li><a class="nav-link" routerLink="/plans" routerLinkActive="is-active">{{ 'nav.plan' | translate }}</a></li>
          <li>
            <app-nav-dropdown
              triggerLabelKey="nav.menu_masters"
              panelId="nav-masters-panel"
              [items]="mastersItems"
              [isOpen]="openDropdownId === 'masters'"
              (opened)="openDropdownId = 'masters'"
              (closed)="openDropdownId = null"
            />
          </li>
        }
        <li><a class="nav-link" routerLink="/public-plans/new" routerLinkActive="is-active">{{ 'nav.new_plan' | translate }}</a></li>
        <!-- 作物スケジュール（/entry-schedule）: 未成熟のためナビから非表示。ルートは残す -->
        <li><a class="nav-link" [href]="reportUrl">{{ 'nav.reports' | translate }}</a></li>
        <li>
          <app-nav-dropdown
            triggerLabelKey="nav.menu_more"
            panelId="nav-more-panel"
            [items]="moreItems"
            [isOpen]="openDropdownId === 'more'"
            (opened)="openDropdownId = 'more'"
            (closed)="openDropdownId = null"
          />
        </li>
      </ul>
      <div class="auth">
        @if (loading) {
          <span class="status">{{ 'status.checking' | translate }}</span>
        } @else if (user) {
          <span class="user-name">{{ displayUserName(user) }}</span>
          <button class="logout-button" type="button" (click)="logout.emit()">
            {{ 'nav.logout' | translate }}
          </button>
        } @else {
          <a class="login-link" routerLink="/login" [queryParams]="loginReturnQuery">
            {{ 'nav.login' | translate }}
          </a>
        }
      </div>
    </nav>
  `,
  styleUrls: ['./navbar.component.css'],
})
export class NavbarComponent {
  private readonly translate = inject(TranslateService);

  @Input() user: CurrentUser | null = null;
  @Input() loading = false;
  @Output() logout = new EventEmitter<void>();

  /** 画面完結: どれか一つだけ開く（interactor 不要） */
  openDropdownId: 'masters' | 'more' | null = null;

  /** モバイルメニューの開閉状態 */
  isMenuOpen = false;

  toggleMenu(): void {
    this.isMenuOpen = !this.isMenuOpen;
  }

  readonly mastersItems: { link: string; labelKey: string }[] = [
    { link: '/farms', labelKey: 'nav.farms' },
    { link: '/crops', labelKey: 'nav.crops' },
    { link: '/fertilizes', labelKey: 'nav.fertilizes' },
    { link: '/pests', labelKey: 'nav.pests' },
    { link: '/pesticides', labelKey: 'nav.pesticides' },
    { link: '/agricultural_tasks', labelKey: 'nav.agricultural_tasks' },
    { link: '/interaction_rules', labelKey: 'nav.interaction_rules' },
  ];

  readonly moreItems: { link: string; labelKey: string }[] = [
    { link: '/about', labelKey: 'nav.about' },
    { link: '/contact', labelKey: 'nav.contact' },
    { link: '/privacy', labelKey: 'nav.privacy' },
    { link: '/terms', labelKey: 'nav.terms' },
  ];

  /** ログイン後に戻る URL（ログインページ自身では付けない）。 */
  get loginReturnQuery(): { return_to?: string } {
    if (typeof window === 'undefined') {
      return {};
    }
    return loginReturnQueryForLocation({
      href: window.location.href || `${window.location.origin}/`,
      pathname: window.location.pathname,
      origin: window.location.origin
    });
  }

  get reportUrl(): string {
    const origin = typeof window !== 'undefined' ? window.location.origin : '';
    const lang = this.translate.currentLang || this.translate.defaultLang || 'ja';
    const reportPath = lang === 'en' ? '/research/en/' : '/research/';
    return `${origin}${reportPath}`;
  }

  /** Dev mock users keep API name「開発者」; show locale-aware short label in the header. */
  displayUserName(user: CurrentUser): string {
    const mapped = this.devMockDisplayName(user.email);
    if (mapped) return mapped;
    return user.name ?? 'User';
  }

  private devMockDisplayName(email: string | null | undefined): string | null {
    const keyByEmail: Record<string, string> = {
      'developer@agrr.dev': 'auth.login.dev_login_as_developer',
      'farmer@agrr.dev': 'auth.login.dev_login_as_farmer',
      'researcher@agrr.dev': 'auth.login.dev_login_as_researcher',
    };
    const key = email ? keyByEmail[email.toLowerCase()] : undefined;
    if (!key) return null;

    const full = this.translate.instant(key);
    const lang = this.translate.currentLang || this.translate.defaultLang || 'ja';
    if (lang === 'ja') return full.replace(/でログイン$/, '');
    if (lang === 'en') return full.replace(/^Login as /i, '');
    if (lang === 'in') return full.replace(/ के रूप में लॉगिन$/, '');
    return full;
  }
}
