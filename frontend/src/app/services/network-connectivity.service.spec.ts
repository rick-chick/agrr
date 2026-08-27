import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { NetworkConnectivityService } from './network-connectivity.service';

describe('NetworkConnectivityService', () => {
  let service: NetworkConnectivityService;

  const setNavigatorOnline = (online: boolean): void => {
    Object.defineProperty(navigator, 'onLine', {
      configurable: true,
      value: online
    });
  };

  beforeEach(() => {
    setNavigatorOnline(true);
    TestBed.configureTestingModule({});
    service = TestBed.inject(NetworkConnectivityService);
  });

  afterEach(() => {
    setNavigatorOnline(true);
    service.ngOnDestroy();
  });

  it('starts online when navigator reports online', () => {
    expect(service.isOnline()).toBe(true);
    expect(service.showReconnectCta()).toBe(false);
  });

  it('tracks offline and online transitions', () => {
    setNavigatorOnline(false);
    window.dispatchEvent(new Event('offline'));
    expect(service.isOnline()).toBe(false);
    expect(service.showReconnectCta()).toBe(false);

    setNavigatorOnline(true);
    window.dispatchEvent(new Event('online'));
    expect(service.isOnline()).toBe(true);
    expect(service.showReconnectCta()).toBe(true);
  });

  it('clears reconnect CTA when dismissed', () => {
    setNavigatorOnline(false);
    window.dispatchEvent(new Event('offline'));
    setNavigatorOnline(true);
    window.dispatchEvent(new Event('online'));

    service.dismissReconnectCta();
    expect(service.showReconnectCta()).toBe(false);
  });
});
