import { Component, input } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { BACKEND_WARMUP_I18N } from '../../../core/backend-warmup/backend-warmup';

@Component({
  selector: 'app-backend-warmup-loading',
  standalone: true,
  imports: [TranslateModule],
  template: `
    <p
      class="backend-warmup-loading"
      [class.backend-warmup-loading--compact]="compact()"
      role="status"
      aria-live="polite"
    >
      <span class="backend-warmup-loading__spinner" aria-hidden="true"></span>
      <span class="backend-warmup-loading__message">{{ messageKey() | translate }}</span>
    </p>
  `,
  styleUrls: ['./backend-warmup-loading.component.css']
})
export class BackendWarmupLoadingComponent {
  readonly messageKey = input<string>(BACKEND_WARMUP_I18N.database);
  readonly compact = input(false);
}
