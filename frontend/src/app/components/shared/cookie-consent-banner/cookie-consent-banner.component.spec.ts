import { ComponentFixture, TestBed } from '@angular/core/testing';
import { BrowserModule } from '@angular/platform-browser';
import { TranslateLoader, TranslateModule } from '@ngx-translate/core';
import { of } from 'rxjs';
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { CookieConsentBannerComponent } from './cookie-consent-banner.component';
import { GoogleAnalyticsService } from '../../../services/google-analytics.service';

interface CookieControlWindow extends Window {
  __disableCookieControl?: boolean;
}

const translations = {
  cookie_consent: {
    title: 'Cookie usage',
    description_html: 'Description',
    privacy_link_text: 'Privacy',
    accept: 'Accept',
    reject: 'Reject',
    aria_label: 'Cookie consent dialog'
  }
};

class DummyLoader implements TranslateLoader {
  getTranslation() {
    return of(translations);
  }
}

describe('CookieConsentBannerComponent', () => {
  let fixture: ComponentFixture<CookieConsentBannerComponent>;
  let component: CookieConsentBannerComponent;
  const googleAnalyticsMock = {
    getStoredConsent: vi.fn(),
    applyStoredConsent: vi.fn(),
    updateConsent: vi.fn()
  };

  beforeEach(async () => {
    vi.clearAllMocks();
    (window as CookieControlWindow).__disableCookieControl = false;

    await TestBed.configureTestingModule({
      imports: [
        BrowserModule,
        CookieConsentBannerComponent,
        TranslateModule.forRoot({
          loader: { provide: TranslateLoader, useClass: DummyLoader }
        })
      ],
      providers: [{ provide: GoogleAnalyticsService, useValue: googleAnalyticsMock }]
    }).compileComponents();

    fixture = TestBed.createComponent(CookieConsentBannerComponent);
    component = fixture.componentInstance;
  });

  it('shows the banner when consent is not stored', () => {
    googleAnalyticsMock.getStoredConsent.mockReturnValue(null);

    fixture.detectChanges();

    expect(component.visible).toBe(true);
    expect(googleAnalyticsMock.applyStoredConsent).not.toHaveBeenCalled();
  });

  it('hides the banner when consent was already stored', () => {
    googleAnalyticsMock.getStoredConsent.mockReturnValue('denied');

    fixture.detectChanges();

    expect(component.visible).toBe(false);
    expect(googleAnalyticsMock.applyStoredConsent).toHaveBeenCalled();
  });

  it('accepting consent updates service and hides banner', () => {
    googleAnalyticsMock.getStoredConsent.mockReturnValue(null);
    fixture.detectChanges();

    component.accept();

    expect(googleAnalyticsMock.updateConsent).toHaveBeenCalledWith(true);
    expect(component.visible).toBe(false);
  });

  it('rejecting consent updates service and hides banner', () => {
    googleAnalyticsMock.getStoredConsent.mockReturnValue(null);
    fixture.detectChanges();

    component.reject();

    expect(googleAnalyticsMock.updateConsent).toHaveBeenCalledWith(false);
    expect(component.visible).toBe(false);
  });

  it('labels dialog with aria-labelledby pointing at the title', () => {
    googleAnalyticsMock.getStoredConsent.mockReturnValue(null);
    fixture.detectChanges();

    const dialog = fixture.nativeElement.querySelector('.cookie-consent-banner');
    const title = fixture.nativeElement.querySelector('.cookie-consent-title');

    expect(dialog.getAttribute('aria-labelledby')).toBe('cookie-consent-dialog-title');
    expect(title?.id).toBe('cookie-consent-dialog-title');
    expect(dialog.getAttribute('aria-label')).toBeNull();
  });

  it('traps Tab focus within the dialog', () => {
    googleAnalyticsMock.getStoredConsent.mockReturnValue(null);
    fixture.detectChanges();

    const buttons = Array.from(
      fixture.nativeElement.querySelectorAll('.cookie-consent-actions button')
    ) as HTMLButtonElement[];
    const accept = buttons[0];
    const reject = buttons[1];

    accept.focus();
    const shiftTab = new KeyboardEvent('keydown', { key: 'Tab', shiftKey: true, bubbles: true });
    dialogDispatch(shiftTab);
    expect(document.activeElement).toBe(reject);

    const tab = new KeyboardEvent('keydown', { key: 'Tab', bubbles: true });
    dialogDispatch(tab);
    expect(document.activeElement).toBe(accept);
  });

  function dialogDispatch(event: KeyboardEvent): void {
    fixture.nativeElement.querySelector('.cookie-consent-banner')?.dispatchEvent(event);
  }

  afterEach(() => {
    delete (window as CookieControlWindow).__disableCookieControl;
  });
});
