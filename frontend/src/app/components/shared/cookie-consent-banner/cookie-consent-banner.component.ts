import { Component, ElementRef, OnInit, ViewChild } from '@angular/core';
import { CommonModule } from '@angular/common';
import { DomSanitizer, SafeHtml } from '@angular/platform-browser';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { COOKIE_CONTROL_UI_DISABLED } from '../../../core/cookie-consent-policy';
import { GoogleAnalyticsService } from '../../../services/google-analytics.service';

type CookieControlWindow = Window & {
  __disableCookieControl?: boolean;
};

const isCookieControlHardDisabled = (): boolean => {
  if (typeof window === 'undefined') {
    return COOKIE_CONTROL_UI_DISABLED;
  }

  const windowWithOverride = window as CookieControlWindow;
  const override = windowWithOverride.__disableCookieControl;
  if (typeof override === 'boolean') {
    return override;
  }

  return COOKIE_CONTROL_UI_DISABLED;
};

@Component({
  selector: 'app-cookie-consent-banner',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  templateUrl: './cookie-consent-banner.component.html',
  styleUrls: ['./cookie-consent-banner.component.css']
})
export class CookieConsentBannerComponent implements OnInit {
  readonly dialogTitleId = 'cookie-consent-dialog-title';
  descriptionHtml: SafeHtml | null = null;
  visible = false;

  @ViewChild('acceptButton') private acceptButton?: ElementRef<HTMLButtonElement>;

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
      queueMicrotask(() => this.focusInitialControl());
    }
    this.descriptionHtml = this.buildDescription();
  }

  onDialogKeydown(event: KeyboardEvent): void {
    if (!this.visible || event.key !== 'Tab') {
      return;
    }

    const card = event.currentTarget as HTMLElement | null;
    if (!card) {
      return;
    }

    const focusables = this.getFocusableElements(card);
    if (focusables.length === 0) {
      return;
    }

    const first = focusables[0];
    const last = focusables[focusables.length - 1];
    const active = document.activeElement;

    if (event.shiftKey && active === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && active === last) {
      event.preventDefault();
      first.focus();
    }
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

  private focusInitialControl(): void {
    this.acceptButton?.nativeElement.focus();
  }

  private getFocusableElements(root: HTMLElement): HTMLElement[] {
    return Array.from(
      root.querySelectorAll<HTMLElement>(
        'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
      )
    );
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
