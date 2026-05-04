import { describe, it, beforeEach, afterEach, expect, vi } from 'vitest';
import { environment } from '../../environments/environment';
import { GoogleAnalyticsService } from './google-analytics.service';

describe('GoogleAnalyticsService', () => {
  let service: GoogleAnalyticsService;
  let storage: Record<string, string>;

  beforeEach(() => {
    storage = {};
    vi.stubGlobal('localStorage', {
      getItem: vi.fn((key: string) => (key in storage ? storage[key] : null)),
      setItem: vi.fn((key: string, value: string) => {
        storage[key] = value;
      }),
      removeItem: vi.fn((key: string) => {
        delete storage[key];
      }),
      clear: vi.fn(() => {
        storage = {};
      })
    });
    environment.enableGoogleAnalytics = true;
    environment.googleAnalyticsMeasurementId = 'G-WNLSL6W4ZT';
    service = new GoogleAnalyticsService();
  });

  afterEach(() => {
    vi.restoreAllMocks();
    delete window.gtag;
    delete window.loadAdSense;
    delete window.dataLayer;
    environment.enableGoogleAnalytics = false;
    environment.googleAdsId = '';
    environment.googleAdsLoginConversionSendTo = '';
    delete window.GOOGLE_ADS_CONVERSION_ID;
    delete window.GOOGLE_ADS_LOGIN_CONVERSION_SEND_TO;
  });

  it('applies stored consent when available', () => {
    window.gtag = vi.fn();
    storage['cookieConsentStatus'] = 'denied';

    service.applyStoredConsent();

    expect(window.gtag).toHaveBeenCalledWith(
      'consent',
      'update',
      expect.objectContaining({
        ad_storage: 'denied',
        analytics_storage: 'denied'
      })
    );
    expect(window.loadAdSense).toBeUndefined();
  });

  it('stores consent and triggers loadAdSense when granted', () => {
    window.gtag = vi.fn();
    window.loadAdSense = vi.fn();

    service.updateConsent(true);

    expect(storage['cookieConsentStatus']).toBe('granted');
    expect(window.gtag).toHaveBeenCalledWith(
      'consent',
      'update',
      expect.objectContaining({
        ad_storage: 'granted',
        analytics_storage: 'granted'
      })
    );
    expect(window.loadAdSense).toHaveBeenCalled();
  });

  it('tracks page views using page_view event (not repeated config)', () => {
    window.gtag = vi.fn();

    service.trackPageView('/foo');

    expect(window.gtag).toHaveBeenCalledWith(
      'event',
      'page_view',
      expect.objectContaining({
        page_path: '/foo',
        anonymize_ip: true
      })
    );
  });

  it('falls back to dataLayer when gtag is unavailable', () => {
    window.dataLayer = [];

    service.trackPageView('/bar');

    expect(window.dataLayer?.length).toBeGreaterThan(0);
    const first = window.dataLayer?.[0];
    expect(Array.from(first as ArrayLike<unknown>)).toEqual([
      'event',
      'page_view',
      expect.objectContaining({ page_path: '/bar' })
    ]);
  });

  it('does nothing when the environment disables analytics', () => {
    environment.enableGoogleAnalytics = false;
    service = new GoogleAnalyticsService();
    window.gtag = vi.fn();

    service.trackPageView('/disabled');

    expect(window.gtag).not.toHaveBeenCalled();
  });

  it('configures Google Ads tag when googleAdsId is set', () => {
    window.gtag = vi.fn();
    environment.googleAdsId = 'AW-TEST123';
    service = new GoogleAnalyticsService();

    expect(window.gtag).toHaveBeenCalledWith(
      'config',
      'AW-TEST123',
      expect.objectContaining({
        send_page_view: false
      })
    );
  });

  it('tracks Google Ads conversion with trimmed send_to', () => {
    window.gtag = vi.fn();
    service.trackAdsConversion({ send_to: ' AW-1/label ', value: 10, currency: 'JPY' });

    expect(window.gtag).toHaveBeenCalledWith(
      'event',
      'conversion',
      expect.objectContaining({
        send_to: 'AW-1/label',
        value: 10,
        currency: 'JPY'
      })
    );
  });

  it('skips conversion when send_to is empty', () => {
    window.gtag = vi.fn();
    service.trackAdsConversion({ send_to: '   ' });
    expect(window.gtag).not.toHaveBeenCalledWith('event', 'conversion', expect.anything());
  });
});
