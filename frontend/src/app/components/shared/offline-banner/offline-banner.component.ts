import { Component, inject } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { ConnectivityService } from '../../../services/connectivity.service';

@Component({
  selector: 'app-offline-banner',
  standalone: true,
  imports: [TranslateModule],
  template: `
    @if (connectivity.isOffline()) {
      <div class="offline-banner offline-banner--offline" role="alert">
        <p class="offline-banner__message">
          {{ 'shared.offline_banner.message' | translate }}
        </p>
      </div>
    } @else if (connectivity.showReconnectedCta()) {
      <div class="offline-banner offline-banner--reconnected" role="status" aria-live="polite">
        <p class="offline-banner__message">
          {{ 'shared.offline_banner.reconnected' | translate }}
        </p>
        <div class="offline-banner__actions">
          <button
            type="button"
            class="offline-banner__reload action-button action-button--primary"
            (click)="reload()"
          >
            {{ 'shared.offline_banner.reload' | translate }}
          </button>
          <button
            type="button"
            class="offline-banner__dismiss action-button action-button--secondary"
            (click)="dismiss()"
          >
            {{ 'common.close' | translate }}
          </button>
        </div>
      </div>
    }
  `,
  styleUrls: ['./offline-banner.component.css']
})
export class OfflineBannerComponent {
  protected readonly connectivity = inject(ConnectivityService);

  reload(): void {
    this.connectivity.reload();
  }

  dismiss(): void {
    this.connectivity.dismissReconnectedCta();
  }
}
