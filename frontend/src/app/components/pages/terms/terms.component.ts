import { Component, inject } from '@angular/core';
import { TranslateModule, TranslateService } from '@ngx-translate/core';

@Component({
  selector: 'app-terms',
  standalone: true,
  imports: [TranslateModule],
  template: `
    <div class="page-content-container">
      <h1 class="page-header">{{ 'pages.terms.heading' | translate }}</h1>
      
      <div class="page-content">
        <p class="page-section-content">{{ 'pages.terms.intro' | translate }}</p>

        <h2 class="page-section-title">{{ 'pages.terms.article1.title' | translate }}</h2>
        <p class="page-section-content">{{ 'pages.terms.article1.content' | translate }}</p>

        <h2 class="page-section-title">{{ 'pages.terms.article2.title' | translate }}</h2>
        <p class="page-section-content">{{ 'pages.terms.article2.intro' | translate }}</p>
        <ul class="page-list">
          @for (item of ('pages.terms.article2.items' | translate); track item) {
            <li>{{ item }}</li>
          }
        </ul>

        <h2 class="page-section-title">{{ 'pages.terms.article3.title' | translate }}</h2>
        <p class="page-section-content">{{ 'pages.terms.article3.content' | translate }}</p>

        <h2 class="page-section-title">{{ 'pages.terms.article4.title' | translate }}</h2>
        <p class="page-section-content">{{ 'pages.terms.article4.intro' | translate }}</p>
        <ul class="page-list">
          @for (item of ('pages.terms.article4.items' | translate); track item) {
            <li>{{ item }}</li>
          }
        </ul>

        <h2 class="page-section-title">{{ 'pages.terms.article5.title' | translate }}</h2>
        <p class="page-section-content">{{ 'pages.terms.article5.content' | translate }}</p>

        <h2 class="page-section-title">{{ 'pages.terms.article6.title' | translate }}</h2>
        <p class="page-section-content">{{ 'pages.terms.article6.intro' | translate }}</p>
        <ul class="page-list">
          @for (item of ('pages.terms.article6.items' | translate); track item) {
            <li>{{ item }}</li>
          }
        </ul>
        <p class="page-section-content">{{ 'pages.terms.article6.note' | translate }}</p>

        <h2 class="page-section-title">{{ 'pages.terms.article7.title' | translate }}</h2>
        <p class="page-section-content">{{ 'pages.terms.article7.content' | translate }}</p>

        <h2 class="page-section-title">{{ 'pages.terms.article8.title' | translate }}</h2>
        <p class="page-section-content">{{ 'pages.terms.article8.content' | translate }}</p>

        <h2 class="page-section-title">{{ 'pages.terms.article9.title' | translate }}</h2>
        <p class="page-section-content">{{ 'pages.terms.article9.content' | translate }}</p>

        <h2 class="page-section-title">{{ 'pages.terms.article10.title' | translate }}</h2>
        <p
          class="page-section-content"
          [innerHTML]="'pages.terms.article10.content_html' | translate: article10ContactParams"
        ></p>

        <p class="page-footer-text-right">{{ 'pages.terms.effective_date' | translate }}</p>
      </div>
    </div>
  `,
  styleUrls: ['./terms.component.css']
})
export class TermsComponent {
  private readonly translate = inject(TranslateService);

  get article10ContactParams(): Record<string, string> {
    const text = this.translate.instant('pages.terms.article10.contact_link_text');
    return { contact_link: `<a href="/contact">${text}</a>` };
  }
}
