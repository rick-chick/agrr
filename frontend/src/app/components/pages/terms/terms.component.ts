import { Component } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { RouterLink } from '@angular/router';

@Component({
  selector: 'app-terms',
  standalone: true,
  imports: [TranslateModule, RouterLink],
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
        <p class="page-section-content">
          {{ 'pages.terms.article10.content' | translate }}
        </p>

        <p class="page-footer-text-right">{{ 'pages.terms.effective_date' | translate }}</p>
      </div>
    </div>
  `,
  styleUrl: './terms.component.css'
})
export class TermsComponent {}
