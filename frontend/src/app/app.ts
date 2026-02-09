import { Component, OnDestroy, OnInit, inject } from '@angular/core';
import { Router, RouterOutlet, NavigationEnd } from '@angular/router';
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
  protected readonly authService = inject(AuthService);
  private readonly router = inject(Router);
  private readonly undoToastService = inject(UndoToastService);
  private readonly googleAnalytics = inject(GoogleAnalyticsService);
  private routerSubscription?: Subscription;
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
    this.translate.use('ja');
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
  }
}
