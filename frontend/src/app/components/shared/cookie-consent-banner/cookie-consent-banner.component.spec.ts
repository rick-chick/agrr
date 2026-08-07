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

  it('marks dialog as modal for assistive tech', () => {
    googleAnalyticsMock.getStoredConsent.mockReturnValue(null);
    fixture.detectChanges();

    const dialog = fixture.nativeElement.querySelector('.cookie-consent-banner');
    expect(dialog.getAttribute('aria-modal')).toBe('true');
  });

  it('focuses accept button when banner becomes visible', () => {
    googleAnalyticsMock.getStoredConsent.mockReturnValue(null);
    fixture.detectChanges();

    const accept = fixture.nativeElement.querySelector('.btn-primary') as HTMLButtonElement;
    expect(document.activeElement).toBe(accept);
  });

  it('wraps Tab focus from last focusable back to first', () => {
    googleAnalyticsMock.getStoredConsent.mockReturnValue(null);
    fixture.detectChanges();

    const dialog = fixture.nativeElement.querySelector('.cookie-consent-banner') as HTMLElement;
    const accept = dialog.querySelector('.btn-primary') as HTMLButtonElement;
    const reject = dialog.querySelector('.btn-secondary') as HTMLButtonElement;
    reject.focus();

    const tabEvent = new KeyboardEvent('keydown', { key: 'Tab', bubbles: true });
    Object.defineProperty(tabEvent, 'currentTarget', { value: dialog });
    component.onDialogKeydown(tabEvent);

    expect(document.activeElement).toBe(accept);
  });

  it('wraps Shift+Tab focus from first focusable back to last', () => {
    googleAnalyticsMock.getStoredConsent.mockReturnValue(null);
    fixture.detectChanges();

    const dialog = fixture.nativeElement.querySelector('.cookie-consent-banner') as HTMLElement;
    const accept = dialog.querySelector('.btn-primary') as HTMLButtonElement;
    const reject = dialog.querySelector('.btn-secondary') as HTMLButtonElement;
    accept.focus();

    const shiftTabEvent = new KeyboardEvent('keydown', {
      key: 'Tab',
      shiftKey: true,
      bubbles: true
    });
    Object.defineProperty(shiftTabEvent, 'currentTarget', { value: dialog });
    component.onDialogKeydown(shiftTabEvent);

    expect(document.activeElement).toBe(reject);
  });

  afterEach(() => {
    delete (window as CookieControlWindow).__disableCookieControl;
  });
});
