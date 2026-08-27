import { Component, inject } from '@angular/core';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { I18nBootstrapStateService } from '../../../core/i18n/i18n-bootstrap-state.service';

@Component({
  selector: 'app-i18n-bootstrap-error-panel',
  standalone: true,
  imports: [TranslateModule],
  template: `
    <div class="page-alert-error i18n-bootstrap-error" role="alert">
      <p>{{ 'i18n.bootstrap.load_failed' | translate }}</p>
      <button
        type="button"
        class="btn btn-secondary i18n-bootstrap-error__retry"
        [disabled]="state.retryInProgress()"
        (click)="retry()"
      >
        {{ 'i18n.bootstrap.retry' | translate }}
      </button>
    </div>
  `,
  styles: [
    `
      .i18n-bootstrap-error {
        margin: 1.5rem auto;
        max-width: 40rem;
        padding: 1rem 1.25rem;
      }

      .i18n-bootstrap-error__retry {
        margin-top: 0.75rem;
      }
    `
  ]
})
export class I18nBootstrapErrorPanelComponent {
  protected readonly state = inject(I18nBootstrapStateService);
  private readonly translate = inject(TranslateService);

  retry(): void {
    void this.state.retry(this.translate);
  }
}
