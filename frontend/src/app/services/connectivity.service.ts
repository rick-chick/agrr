import { Injectable, OnDestroy, signal } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class ConnectivityService implements OnDestroy {
  private readonly offlineSignal = signal(false);
  private readonly reconnectedSignal = signal(false);
  private wasOfflineDuringSession = false;

  readonly isOffline = this.offlineSignal.asReadonly();
  readonly showReconnectedCta = this.reconnectedSignal.asReadonly();

  private readonly onOffline = () => {
    this.wasOfflineDuringSession = true;
    this.offlineSignal.set(true);
    this.reconnectedSignal.set(false);
  };

  private readonly onOnline = () => {
    this.offlineSignal.set(false);
    if (this.wasOfflineDuringSession) {
      this.reconnectedSignal.set(true);
    }
  };

  constructor() {
    if (typeof window === 'undefined') {
      return;
    }

    window.addEventListener('offline', this.onOffline);
    window.addEventListener('online', this.onOnline);
  }

  ngOnDestroy(): void {
    if (typeof window === 'undefined') {
      return;
    }

    window.removeEventListener('offline', this.onOffline);
    window.removeEventListener('online', this.onOnline);
  }

  dismissReconnectedCta(): void {
    this.reconnectedSignal.set(false);
  }

  reload(): void {
    window.location.reload();
  }

  /** @internal test-only */
  setOfflineForTest(offline: boolean): void {
    this.offlineSignal.set(offline);
  }

  /** @internal test-only */
  setReconnectedCtaForTest(visible: boolean): void {
    this.reconnectedSignal.set(visible);
  }
}
