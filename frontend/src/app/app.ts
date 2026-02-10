import { Component, OnDestroy, OnInit, inject } from '@angular/core';
import { Router, RouterOutlet, NavigationEnd } from '@angular/router';
import { Title } from '@angular/platform-browser';
import { TranslateService } from '@ngx-translate/core';
import { filter, Subscription } from 'rxjs';
import { NavbarComponent } from './components/shared/navbar/navbar.component';
import { FooterComponent } from './components/shared/footer/footer.component';
import { FlashMessageComponent } from './components/shared/flash-message/flash-message.component';
import { UndoToastComponent } from './components/shared/undo-toast/undo-toast.component';
import { CookieConsentBannerComponent } from './components/shared/cookie-consent-banner/cookie-consent-banner.component';
import { GoogleAnalyticsService } from './services/google-analytics.service';
import { AuthService } from './services/auth.service';
import { UndoToastService } from './services/undo-toast.service';
import { getApiBaseUrl } from './core/api-base-url';

/** Maps browser language codes to supported Angular i18n keys. en→en, hi→in, others→ja */
function detectBrowserLang(): 'ja' | 'en' | 'in' {
  const langs: readonly string[] =
    typeof navigator !== 'undefined' && navigator.languages?.length
      ? [...navigator.languages]
      : typeof navigator !== 'undefined' && navigator.language
        ? [navigator.language]
        : [];
  for (const raw of langs) {
    const code = raw.split('-')[0].toLowerCase();
    if (code === 'en') return 'en';
    if (code === 'hi') return 'in';
    if (code === 'ja') return 'ja';
  }
  return 'ja';
}

/** Rails uses 'us' for English; ja/in stay as-is */
function toRailsLocale(angularLang: 'ja' | 'en' | 'in'): string {
  return angularLang === 'en' ? 'us' : angularLang;
}

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [
    RouterOutlet,
    NavbarComponent,
    FooterComponent,
    FlashMessageComponent,
    UndoToastComponent,
    CookieConsentBannerComponent
  ],
  templateUrl: './app.html',
  styleUrls: ['./app.css']
})
export class App implements OnInit, OnDestroy {
  private readonly translate = inject(TranslateService);
  private readonly title = inject(Title);
  protected readonly authService = inject(AuthService);
  private readonly router = inject(Router);
  private readonly undoToastService = inject(UndoToastService);
  private readonly googleAnalytics = inject(GoogleAnalyticsService);
  private routerSubscription?: Subscription;
  private langChangeSubscription?: Subscription;
  protected readonly apiBaseUrl = getApiBaseUrl();

  performUndo(): void {
    this.undoToastService.performUndo();
  }

  logout(): void {
    this.authService.logout().subscribe({
      next: () => {
        this.router.navigate(['/login']);
      },
      error: () => {
        this.router.navigate(['/login']);
      }
    });
  }

  ngOnInit(): void {
    this.translate.addLangs(['ja', 'en', 'in']);
    this.translate.setDefaultLang('ja');

    const initialLang = detectBrowserLang();
    this.translate.use(initialLang);
    if (typeof document !== 'undefined') {
      document.cookie = `locale=${toRailsLocale(initialLang)}; path=/; max-age=31536000`;
    }

    // Set initial page title when translations are loaded
    this.translate.get('meta.default.title').subscribe((title: string) => {
      this.setPageTitle(title);
    });
    
    // Update page title when language changes
    this.langChangeSubscription = this.translate.onLangChange.subscribe(() => {
      this.setPageTitle(this.translate.instant('meta.default.title'));
    });
    
    this.googleAnalytics.applyStoredConsent();
    this.routerSubscription = this.router.events
      .pipe(filter((event): event is NavigationEnd => event instanceof NavigationEnd))
      .subscribe((event) => {
        this.googleAnalytics.trackPageView(event.urlAfterRedirects);
      });
    this.authService.loadCurrentUser().subscribe();
  }

  ngOnDestroy(): void {
    this.routerSubscription?.unsubscribe();
    this.langChangeSubscription?.unsubscribe();
  }

  private setPageTitle(title: string): void {
    if (title) {
      this.title.setTitle(title);
    }
  }
}
