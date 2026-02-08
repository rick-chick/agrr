import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { DomSanitizer, SafeHtml } from '@angular/platform-browser';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { GoogleAnalyticsService } from '../../../services/google-analytics.service';

type CookieControlWindow = Window & {
  __disableCookieControl?: boolean;
};

const COOKIE_CONTROL_DEFAULT_DISABLED = true;

const isCookieControlHardDisabled = (): boolean => {
  if (typeof window === 'undefined') {
    return COOKIE_CONTROL_DEFAULT_DISABLED;
  }

  const windowWithOverride = window as CookieControlWindow;
  const override = windowWithOverride.__disableCookieControl;
  if (typeof override === 'boolean') {
    return override;
  }

  return COOKIE_CONTROL_DEFAULT_DISABLED;
};

@Component({
  selector: 'app-cookie-consent-banner',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  templateUrl: './cookie-consent-banner.component.html',
  styleUrls: ['./cookie-consent-banner.component.css']
})
export class CookieConsentBannerComponent implements OnInit {
  descriptionHtml: SafeHtml | null = null;
  visible = false;

  constructor(
    private readonly translate: TranslateService,
    private readonly sanitizer: DomSanitizer,
    private readonly googleAnalytics: GoogleAnalyticsService
  ) {}

  ngOnInit(): void {
    if (isCookieControlHardDisabled()) {
      this.googleAnalytics.updateConsent(true);
      return;
    }

    const stored = this.googleAnalytics.getStoredConsent();
    if (stored) {
      this.googleAnalytics.applyStoredConsent();
    } else {
      this.visible = true;
    }
    this.descriptionHtml = this.buildDescription();
  }

  accept(): void {
    this.googleAnalytics.updateConsent(true);
    this.hide();
  }

  reject(): void {
    this.googleAnalytics.updateConsent(false);
    this.hide();
  }

  private hide(): void {
    this.visible = false;
  }

  private buildDescription(): SafeHtml {
    const description = this.translate.instant('cookie_consent.description_html');
    const linkText = this.translate.instant('cookie_consent.privacy_link_text');
    const link = `<a class="cookie-consent-link" href="/privacy" target="_blank" rel="noopener">${linkText}</a>`;
    const formatted = description.includes('%{privacy_link}')
      ? description.replace('%{privacy_link}', link)
      : `${description} ${link}`;
    return this.sanitizer.bypassSecurityTrustHtml(formatted);
  }
}
