import { Injectable, OnDestroy, signal } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class NetworkConnectivityService implements OnDestroy {
  readonly isOnline = signal(this.readNavigatorOnline());
  readonly showReconnectCta = signal(false);

  private readonly handleOnline = (): void => {
    const wasOffline = !this.isOnline();
    this.isOnline.set(true);
    if (wasOffline) {
      this.showReconnectCta.set(true);
    }
  };

  private readonly handleOffline = (): void => {
    this.isOnline.set(false);
    this.showReconnectCta.set(false);
  };

  constructor() {
    if (typeof window !== 'undefined') {
      window.addEventListener('online', this.handleOnline);
      window.addEventListener('offline', this.handleOffline);
    }
  }

  ngOnDestroy(): void {
    if (typeof window !== 'undefined') {
      window.removeEventListener('online', this.handleOnline);
      window.removeEventListener('offline', this.handleOffline);
    }
  }

  dismissReconnectCta(): void {
    this.showReconnectCta.set(false);
  }

  private readNavigatorOnline(): boolean {
    if (typeof navigator === 'undefined') {
      return true;
    }
    return navigator.onLine;
  }
}
