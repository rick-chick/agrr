import { Component, inject } from '@angular/core';
import { TranslateModule, TranslateService } from '@ngx-translate/core';

@Component({
  selector: 'app-privacy',
  standalone: true,
  imports: [TranslateModule],
  template: `
    <div class="page-content-container">
      <h1 class="page-header">{{ 'pages.privacy.heading' | translate }}</h1>
      
      <div class="page-content">
        <p class="page-section-content" [innerHTML]="'pages.privacy.intro_html' | translate"></p>

        <h2 class="page-section-title">{{ 'pages.privacy.section1.title' | translate }}</h2>
        <p class="page-section-content">{{ 'pages.privacy.section1.intro' | translate }}</p>
        <ul class="page-list">
          @for (item of ('pages.privacy.section1.items' | translate); track item) {
            <li>{{ item }}</li>
          }
        </ul>

        <h2 class="page-section-title">{{ 'pages.privacy.section2.title' | translate }}</h2>
        <p class="page-section-content">{{ 'pages.privacy.section2.intro' | translate }}</p>
        <ul class="page-list">
          @for (item of ('pages.privacy.section2.items' | translate); track item) {
            <li>{{ item }}</li>
          }
        </ul>

        <h2 class="page-section-title">{{ 'pages.privacy.section3.title' | translate }}</h2>
        <p class="page-section-content">{{ 'pages.privacy.section3.intro' | translate }}</p>
        <ul class="page-list">
          @for (item of ('pages.privacy.section3.items' | translate); track item) {
            <li>{{ item }}</li>
          }
        </ul>

        <h2 class="page-section-title">{{ 'pages.privacy.section4.title' | translate }}</h2>
        <p class="page-section-content" [innerHTML]="'pages.privacy.section4.content_html' | translate"></p>

        <h2 class="page-section-title">{{ 'pages.privacy.section5.title' | translate }}</h2>
        <p class="page-section-content" [innerHTML]="'pages.privacy.section5.content_html' | translate"></p>

        <h2 class="page-section-title">{{ 'pages.privacy.section6.title' | translate }}</h2>
        <p class="page-section-content">{{ 'pages.privacy.section6.content' | translate }}</p>

        <h2 class="page-section-title">{{ 'pages.privacy.section7.title' | translate }}</h2>
        <p class="page-section-content">{{ 'pages.privacy.section7.content' | translate }}</p>

        <h2 class="page-section-title">{{ 'pages.privacy.section8.title' | translate }}</h2>
        <p
          class="page-section-content"
          [innerHTML]="'pages.privacy.section8.content_html' | translate: section8ContactParams"
        ></p>

        <p class="page-footer-text-right">{{ 'pages.privacy.last_updated' | translate }}</p>
      </div>
    </div>
  `,
  styleUrls: ['./privacy.component.css']
})
export class PrivacyComponent {
  private readonly translate = inject(TranslateService);

  get section8ContactParams(): Record<string, string> {
    const text = this.translate.instant('pages.privacy.section8.contact_link_text');
    return { contact_link: `<a href="/contact">${text}</a>` };
  }
}
