import { Component, OnDestroy, OnInit, inject } from '@angular/core';
import { Router, RouterOutlet, NavigationEnd } from '@angular/router';
import { Meta, Title } from '@angular/platform-browser';
import { TranslateService } from '@ngx-translate/core';
import { filter, Subscription, take } from 'rxjs';
import { getGoogleAdsLoginConversionSendTo } from './core/google-ads-runtime-config';
import { NavbarComponent } from './components/shared/navbar/navbar.component';
import { FooterComponent } from './components/shared/footer/footer.component';
import { FlashMessageComponent } from './components/shared/flash-message/flash-message.component';
import { UndoToastComponent } from './components/shared/undo-toast/undo-toast.component';
import { CookieConsentBannerComponent } from './components/shared/cookie-consent-banner/cookie-consent-banner.component';
import { GoogleAnalyticsService } from './services/google-analytics.service';
import { AuthService } from './services/auth.service';
import { UndoToastService } from './services/undo-toast.service';
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

/** BCP 47 language for <html lang> */
function documentHtmlLang(angularLang: 'ja' | 'en' | 'in'): string {
  return angularLang === 'in' ? 'hi' : angularLang;
}

/** Open Graph locale */
function ogLocale(angularLang: 'ja' | 'en' | 'in'): string {
  if (angularLang === 'ja') return 'ja_JP';
  if (angularLang === 'en') return 'en_US';
  return 'hi_IN';
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
  private readonly meta = inject(Meta);
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
    this.translate.addLangs(['ja', 'en', 'in']);
    this.translate.setDefaultLang('ja');

    const initialLang = detectBrowserLang();
    this.translate.use(initialLang);
    if (typeof document !== 'undefined') {
      document.cookie = `locale=${toRailsLocale(initialLang)}; path=/; max-age=31536000`;
    }

    this.translate
      .get([
        'meta.default.title',
        'meta.default.description',
        'meta.default.keywords',
        'meta.default.og_description',
      ])
      .subscribe(() => {
        this.refreshSeoMeta();
      });

    this.langChangeSubscription = this.translate.onLangChange.subscribe(() => {
      this.refreshSeoMeta();
    });

    this.googleAnalytics.applyStoredConsent();

    this.authService
      .loadCurrentUser()
      .pipe(take(1))
      .subscribe(() => {
        void this.maybeTrackGoogleAdsAfterOAuthLanding();
      });

    this.routerSubscription = this.router.events
      .pipe(filter((event): event is NavigationEnd => event instanceof NavigationEnd))
      .subscribe((event) => {
        this.googleAnalytics.trackPageView(event.urlAfterRedirects);
        this.refreshSeoMeta();
      });
  }

  ngOnDestroy(): void {
    this.routerSubscription?.unsubscribe();
    this.langChangeSubscription?.unsubscribe();
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

  private refreshSeoMeta(): void {
    const angularLang = (this.translate.currentLang || 'ja') as 'ja' | 'en' | 'in';
    if (typeof document !== 'undefined') {
      document.documentElement.lang = documentHtmlLang(angularLang);
    }

    const title = this.translate.instant('meta.default.title');
    const description = this.translate.instant('meta.default.description');
    const keywords = this.translate.instant('meta.default.keywords');
    let ogDescription = this.translate.instant('meta.default.og_description');
    if (!ogDescription || ogDescription.startsWith('meta.default.')) {
      ogDescription = description;
    }

    if (title && !title.startsWith('meta.default.')) {
      this.title.setTitle(title);
    }
    if (description && !description.startsWith('meta.default.')) {
      this.meta.updateTag({ name: 'description', content: description });
    }
    if (keywords && !keywords.startsWith('meta.default.')) {
      this.meta.updateTag({ name: 'keywords', content: keywords });
    }

    const origin = typeof window !== 'undefined' ? window.location.origin : '';
    const path = typeof window !== 'undefined' ? window.location.pathname : '/';
    const ogUrl = origin ? `${origin}${path.split('?')[0]}` : '';

    // Do not set og:image / twitter:image to favicon.ico (16–32px): it breaks
    // summary_large_image and degrades Facebook OG. Use twitter:card summary until
    // a dedicated image (e.g. ≥300×157, ideally 1200×630) is shipped under /assets.
    this.meta.removeTag('property="og:image"');
    this.meta.removeTag('name="twitter:image"');
    this.meta.removeTag('name="twitter:image:alt"');

    if (title && !title.startsWith('meta.default.')) {
      this.meta.updateTag({ property: 'og:title', content: title });
      this.meta.updateTag({ name: 'twitter:title', content: title });
    }
    if (ogDescription && !ogDescription.startsWith('meta.default.')) {
      this.meta.updateTag({ property: 'og:description', content: ogDescription });
      this.meta.updateTag({ name: 'twitter:description', content: ogDescription });
    }
    if (ogUrl) {
      this.meta.updateTag({ property: 'og:url', content: ogUrl });
    }
    this.meta.updateTag({ property: 'og:type', content: 'website' });
    this.meta.updateTag({ property: 'og:locale', content: ogLocale(angularLang) });
    this.meta.updateTag({ property: 'og:site_name', content: 'AGRR' });
    this.meta.updateTag({ name: 'twitter:card', content: 'summary' });
  }
}
