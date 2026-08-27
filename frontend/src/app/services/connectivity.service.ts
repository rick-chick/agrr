import { Injectable, OnDestroy, signal } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class ConnectivityService implements OnDestroy {
  private readonly offlineSignal = signal(
    typeof navigator !== 'undefined' ? !navigator.onLine : false
  );
  private readonly reconnectedSignal = signal(false);

  readonly isOffline = this.offlineSignal.asReadonly();
  readonly showReconnectedCta = this.reconnectedSignal.asReadonly();

  private readonly onOffline = () => {
    this.offlineSignal.set(true);
    this.reconnectedSignal.set(false);
  };

  private readonly onOnline = () => {
    this.offlineSignal.set(false);
    this.reconnectedSignal.set(true);
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
