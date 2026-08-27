import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ConnectivityService } from './connectivity.service';

describe('ConnectivityService', () => {
  let service: ConnectivityService;
  const listeners = new Map<string, Set<EventListener>>();

  const dispatchWindowEvent = (type: 'online' | 'offline') => {
    listeners.get(type)?.forEach((listener) => listener(new Event(type)));
  };

  beforeEach(() => {
    listeners.clear();

    vi.spyOn(window, 'addEventListener').mockImplementation((type, listener) => {
      const eventType = String(type);
      if (!listeners.has(eventType)) {
        listeners.set(eventType, new Set());
      }
      listeners.get(eventType)?.add(listener as EventListener);
    });

    Object.defineProperty(window.navigator, 'onLine', {
      configurable: true,
      value: true
    });

    TestBed.configureTestingModule({});
    service = TestBed.inject(ConnectivityService);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('starts online when navigator.onLine is true', () => {
    expect(service.isOffline()).toBe(false);
    expect(service.showReconnectedCta()).toBe(false);
  });

  it('reflects offline when window offline fires', () => {
    dispatchWindowEvent('offline');

    expect(service.isOffline()).toBe(true);
    expect(service.showReconnectedCta()).toBe(false);
  });

  it('clears offline and shows reload CTA when window online fires', () => {
    dispatchWindowEvent('offline');
    dispatchWindowEvent('online');

    expect(service.isOffline()).toBe(false);
    expect(service.showReconnectedCta()).toBe(true);
  });

  it('dismisses reload CTA without reloading', () => {
    dispatchWindowEvent('offline');
    dispatchWindowEvent('online');

    service.dismissReconnectedCta();

    expect(service.showReconnectedCta()).toBe(false);
  });
});
