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

class DummyLoader implements TranslateLoader {
  getTranslation() {
    return of({});
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
  afterEach(() => {
    delete (window as CookieControlWindow).__disableCookieControl;
  });
});
