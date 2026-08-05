import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

@Component({
  selector: 'app-not-found',
  standalone: true,
  imports: [TranslateModule, RouterLink],
  template: `
    <div class="page-content-container">
      <div class="page-header">
        <h1 class="page-title">{{ 'pages.notFound.title' | translate }}</h1>
      </div>
      <div class="page-content">
        <p class="page-section-content">{{ 'pages.notFound.message' | translate }}</p>
        <p>
          <a routerLink="/" class="primary-button">{{ 'pages.notFound.backHome' | translate }}</a>
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
export class NotFoundComponent {}
