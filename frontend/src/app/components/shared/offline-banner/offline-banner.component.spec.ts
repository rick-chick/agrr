import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ConnectivityService } from '../../../services/connectivity.service';
import { OfflineBannerComponent } from './offline-banner.component';

describe('OfflineBannerComponent', () => {
  let fixture: ComponentFixture<OfflineBannerComponent>;
  let connectivity: ConnectivityService;
  let translate: TranslateService;

  beforeEach(async () => {
    Object.defineProperty(window.navigator, 'onLine', {
      configurable: true,
      value: true
    });

    await TestBed.configureTestingModule({
      imports: [OfflineBannerComponent, TranslateModule.forRoot()]
    }).compileComponents();

    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      shared: {
        offline_banner: {
          message: 'You are offline.',
          reconnected: 'Connection restored.',
          reload: 'Reload'
        }
      },
      common: {
        close: 'Close'
      }
    });
    translate.use('en');

    connectivity = TestBed.inject(ConnectivityService);
    fixture = TestBed.createComponent(OfflineBannerComponent);
  });

  afterEach(() => {
    fixture.destroy();
  });

  it('does not render when online', () => {
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('[role="alert"]')).toBeNull();
    expect(fixture.nativeElement.querySelector('.offline-banner')).toBeNull();
  });

  it('renders offline banner with role=alert when offline', () => {
    connectivity.setOfflineForTest(true);
    fixture.detectChanges();

    const banner = fixture.nativeElement.querySelector('[role="alert"]');
    expect(banner).toBeTruthy();
    expect(banner.textContent).toContain('You are offline.');
  });

  it('hides offline banner and shows reload CTA after reconnect', () => {
    connectivity.setOfflineForTest(true);
    fixture.detectChanges();

    connectivity.setOfflineForTest(false);
    connectivity.setReconnectedCtaForTest(true);
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('[role="alert"]')).toBeNull();

    const reloadButton = fixture.nativeElement.querySelector(
      '.offline-banner__reload'
    ) as HTMLButtonElement;
    expect(reloadButton).toBeTruthy();
    expect(reloadButton.textContent).toContain('Reload');
  });

  it('reload button triggers page reload', () => {
    const reloadSpy = vi.spyOn(connectivity, 'reload').mockImplementation(() => undefined);

    connectivity.setOfflineForTest(false);
    connectivity.setReconnectedCtaForTest(true);
    fixture.detectChanges();

    const reloadButton = fixture.nativeElement.querySelector(
      '.offline-banner__reload'
    ) as HTMLButtonElement;
    reloadButton.click();

    expect(reloadSpy).toHaveBeenCalledTimes(1);
  });
});
