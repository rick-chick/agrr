import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import en from '../../../../assets/i18n/en.json';
import { NetworkConnectivityService } from '../../../services/network-connectivity.service';
import { OfflineBannerComponent } from './offline-banner.component';

describe('OfflineBannerComponent', () => {
  let fixture: ComponentFixture<OfflineBannerComponent>;
  let component: OfflineBannerComponent;
  let connectivity: NetworkConnectivityService;

  const setNavigatorOnline = (online: boolean): void => {
    Object.defineProperty(navigator, 'onLine', {
      configurable: true,
      value: online
    });
  };

  const dispatchConnectivityEvent = (type: 'online' | 'offline'): void => {
    window.dispatchEvent(new Event(type));
  };

  beforeEach(async () => {
    setNavigatorOnline(true);

    await TestBed.configureTestingModule({
      imports: [OfflineBannerComponent, TranslateModule.forRoot()]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    connectivity = TestBed.inject(NetworkConnectivityService);
    fixture = TestBed.createComponent(OfflineBannerComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  afterEach(() => {
    setNavigatorOnline(true);
    connectivity.isOnline.set(true);
    connectivity.showReconnectCta.set(false);
  });

  it('hides banner when online and no reconnect CTA is pending', () => {
    expect(fixture.nativeElement.querySelector('.offline-banner')).toBeNull();
  });

  it('shows offline alert banner when window goes offline', () => {
    setNavigatorOnline(false);
    dispatchConnectivityEvent('offline');
    fixture.detectChanges();

    const banner = fixture.nativeElement.querySelector('.offline-banner--offline');
    expect(banner).toBeTruthy();
    expect(banner.getAttribute('role')).toBe('alert');
    expect(banner.textContent).toContain('You are offline');
  });

  it('dismisses offline banner and shows reload CTA when window goes online', () => {
    setNavigatorOnline(false);
    dispatchConnectivityEvent('offline');
    fixture.detectChanges();

    setNavigatorOnline(true);
    dispatchConnectivityEvent('online');
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.offline-banner--offline')).toBeNull();
    const reconnect = fixture.nativeElement.querySelector('.offline-banner--reconnect');
    expect(reconnect).toBeTruthy();
    expect(reconnect.textContent).toContain('Back online');
    expect(reconnect.textContent).toContain('Reload');
  });

  it('reloads the page when reconnect CTA is clicked', () => {
    const reloadSpy = vi.spyOn(component, 'reload').mockImplementation(() => undefined);

    setNavigatorOnline(false);
    dispatchConnectivityEvent('offline');
    setNavigatorOnline(true);
    dispatchConnectivityEvent('online');
    fixture.detectChanges();

    const reloadButton = fixture.nativeElement.querySelector('.offline-banner__reload') as HTMLButtonElement;
    reloadButton.click();

    expect(reloadSpy).toHaveBeenCalledTimes(1);
    reloadSpy.mockRestore();
  });

  it('dismisses reconnect CTA without reloading', () => {
    setNavigatorOnline(false);
    dispatchConnectivityEvent('offline');
    setNavigatorOnline(true);
    dispatchConnectivityEvent('online');
    fixture.detectChanges();

    const dismissButton = fixture.nativeElement.querySelector('.offline-banner__dismiss') as HTMLButtonElement;
    dismissButton.click();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.offline-banner')).toBeNull();
    expect(connectivity.showReconnectCta()).toBe(false);
  });
});
