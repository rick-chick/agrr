import { Component } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';

@Component({
  selector: 'app-error-fallback',
  standalone: true,
  imports: [TranslateModule],
  template: `
    <div class="page-content-container app-error-fallback">
      <div class="page-header">
        <h1 class="page-title">{{ 'pages.errorFallback.title' | translate }}</h1>
      </div>
      <div class="page-content">
        <p class="page-section-content">{{ 'pages.errorFallback.message' | translate }}</p>
        <p>
          <button type="button" class="btn btn-primary" (click)="reload()">
            {{ 'pages.errorFallback.reload' | translate }}
          </button>
        </p>
      </div>
    </div>
  `,
  styles: [
    `
      :host {
        display: block;
      }
    `
  ]
})
export class ErrorFallbackComponent {
  reload(): void {
    window.location.reload();
  }
}
