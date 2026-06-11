import { Component, OnDestroy, OnInit, inject } from '@angular/core';
import { Router, RouterOutlet, NavigationEnd } from '@angular/router';
import { TranslateService } from '@ngx-translate/core';
import { filter, Subscription, take } from 'rxjs';
import { getGoogleAdsLoginConversionSendTo } from './core/google-ads-runtime-config';
import { AppSeoMetaService } from './core/seo/app-seo-meta.service';
import { NavbarComponent } from './components/shared/navbar/navbar.component';
import { FooterComponent } from './components/shared/footer/footer.component';
import { FlashMessageComponent } from './components/shared/flash-message/flash-message.component';
import { UndoToastComponent } from './components/shared/undo-toast/undo-toast.component';
import { CookieConsentBannerComponent } from './components/shared/cookie-consent-banner/cookie-consent-banner.component';
import { GoogleAnalyticsService } from './services/google-analytics.service';
import { POST_LOGIN_QUERY_PARAM } from './components/auth/login/login-auth-urls';
import { AuthService } from './services/auth.service';
import { UndoToastService } from './services/undo-toast.service';

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
  private readonly seoMeta = inject(AppSeoMetaService);
  protected readonly authService = inject(AuthService);
  private readonly router = inject(Router);
  private readonly undoToastService = inject(UndoToastService);
  private readonly googleAnalytics = inject(GoogleAnalyticsService);
  private routerSubscription?: Subscription;
  private langChangeSubscription?: Subscription;

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
    this.seoMeta.refreshDefaultMeta();

    this.langChangeSubscription = this.translate.onLangChange.subscribe(() => {
      this.seoMeta.refreshDefaultMeta();
    });

    this.googleAnalytics.applyStoredConsent();

    this.authService
      .loadCurrentUser()
      .pipe(take(1))
      .subscribe(() => {
        void this.handleOAuthLandingSideEffects();
      });

    this.routerSubscription = this.router.events
      .pipe(filter((event): event is NavigationEnd => event instanceof NavigationEnd))
      .subscribe((event) => {
        this.googleAnalytics.trackPageView(event.urlAfterRedirects);
        this.seoMeta.refreshDefaultMeta();
      });
  }

  ngOnDestroy(): void {
    this.routerSubscription?.unsubscribe();
    this.langChangeSubscription?.unsubscribe();
  }

  private async handleOAuthLandingSideEffects(): Promise<void> {
    await this.maybeTrackGoogleAdsAfterOAuthLanding();
    await this.maybeNavigatePostLogin();
  }

  /** 認証必須パスは `/?_post_login=` 経由で着地 — セッション確認後にクライアント遷移 */
  private async maybeNavigatePostLogin(): Promise<void> {
    const tree = this.router.parseUrl(this.router.url);
    const postLogin = tree.queryParams[POST_LOGIN_QUERY_PARAM];
    if (typeof postLogin !== 'string' || !postLogin) {
      return;
    }
    if (!this.authService.user()) {
      return;
    }

    const target = this.router.parseUrl(postLogin.startsWith('/') ? postLogin : `/${postLogin}`);
    await this.router.navigateByUrl(target, { replaceUrl: true });
  }

  /** OAuth（または開発用モックログイン）直後のみバックエンドが付与するクエリ `_agrr_oauth=1` を消費して Google 広告コンバージョンを送る。 */
  private async maybeTrackGoogleAdsAfterOAuthLanding(): Promise<void> {
    const tree = this.router.parseUrl(this.router.url);
    if (tree.queryParams['_agrr_oauth'] !== '1') {
      return;
    }

    const sendTo = getGoogleAdsLoginConversionSendTo();
    if (this.authService.user() && sendTo) {
      this.googleAnalytics.trackAdsConversion({ send_to: sendTo });
    }

    delete tree.queryParams['_agrr_oauth'];
    await this.router.navigateByUrl(tree, { replaceUrl: true });
  }
}
