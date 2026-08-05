import { Component, OnDestroy, OnInit, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { AppSeoMetaService } from '../../../core/seo/app-seo-meta.service';

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
export class NotFoundComponent implements OnInit, OnDestroy {
  private readonly seoMeta = inject(AppSeoMetaService);

  ngOnInit(): void {
    this.seoMeta.applyNoIndexMeta();
  }

  ngOnDestroy(): void {
    this.seoMeta.removeNoIndexMeta();
  }
}
