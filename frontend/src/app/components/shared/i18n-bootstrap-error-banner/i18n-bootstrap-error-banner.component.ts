import { Component, inject } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { I18nBootstrapStateService } from '../../../core/i18n/i18n-bootstrap-state.service';

@Component({
  selector: 'app-i18n-bootstrap-error-banner',
  standalone: true,
  imports: [TranslateModule],
  template: `
    @if (i18nBootstrap.loadFailed()) {
      <div class="page-alert-error i18n-bootstrap-error" role="alert">
        <p>{{ 'common.i18n.bootstrap.load_failed' | translate }}</p>
        <button
          type="button"
          class="btn btn-secondary i18n-bootstrap-error__retry"
          [disabled]="i18nBootstrap.retrying()"
          (click)="retry()"
        >
          {{ 'common.i18n.bootstrap.retry' | translate }}
        </button>
      </div>
    }
  `,
  styleUrls: ['./i18n-bootstrap-error-banner.component.css']
})
export class I18nBootstrapErrorBannerComponent {
  protected readonly i18nBootstrap = inject(I18nBootstrapStateService);

  retry(): void {
    void this.i18nBootstrap.retry();
  }
}
