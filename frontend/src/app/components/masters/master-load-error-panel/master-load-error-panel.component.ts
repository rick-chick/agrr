import { Component, input, output } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { BackendWarmupLoadingComponent } from '../../shared/backend-warmup-loading/backend-warmup-loading.component';

@Component({
  selector: 'app-master-load-error-panel',
  standalone: true,
  imports: [RouterLink, TranslateModule, BackendWarmupLoadingComponent],
  template: `
    @if (isWarmupError()) {
      <div class="master-load-warmup" role="status">
        <app-backend-warmup-loading [messageKey]="errorKey()" />
        <div class="master-load-warmup__actions">
          <button type="button" class="btn btn-secondary master-load-warmup__retry" (click)="retry.emit()">
            {{ 'common.backend_warmup.reload' | translate }}
          </button>
        </div>
      </div>
    } @else {
      <div class="page-alert-error master-load-error" role="alert">
        <p>{{ errorKey() | translate }}</p>
        <div class="master-load-error__actions">
          <a [routerLink]="listLink()" class="btn btn-secondary master-load-error__back">
            {{ backLabelKey() | translate }}
          </a>
          <button type="button" class="btn btn-secondary master-load-error__retry" (click)="retry.emit()">
            {{ 'masters.load_error.retry' | translate }}
          </button>
        </div>
      </div>
    }
  `,
  styleUrls: ['./master-load-error-panel.component.css']
})
export class MasterLoadErrorPanelComponent {
  readonly errorKey = input.required<string>();
  readonly listLink = input.required<string | readonly (string | number)[]>();
  readonly backLabelKey = input.required<string>();
  readonly isWarmupError = input(false);
  readonly retry = output<void>();
}
