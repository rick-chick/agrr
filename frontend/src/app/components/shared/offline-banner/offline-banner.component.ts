import { Component, inject } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { NetworkConnectivityService } from '../../../services/network-connectivity.service';

@Component({
  selector: 'app-offline-banner',
  standalone: true,
  imports: [TranslateModule],
  templateUrl: './offline-banner.component.html',
  styleUrls: ['./offline-banner.component.css']
})
export class OfflineBannerComponent {
  protected readonly connectivity = inject(NetworkConnectivityService);

  reload(): void {
    if (typeof window !== 'undefined') {
      window.location.reload();
    }
  }

  dismissReconnect(): void {
    this.connectivity.dismissReconnectCta();
  }
}
