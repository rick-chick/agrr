import { Component } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { RouterLink } from '@angular/router';

@Component({
  selector: 'app-privacy',
  standalone: true,
  imports: [TranslateModule, RouterLink],
  template: `
    <div class="page-content-container">
      <h1 class="page-header">{{ 'pages.privacy.heading' | translate }}</h1>
      
      <div class="page-content">
        <p class="page-section-content" [innerHTML]="'pages.privacy.intro' | translate"></p>

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
        <p class="page-section-content" [innerHTML]="'pages.privacy.section4.content' | translate"></p>

        <h2 class="page-section-title">{{ 'pages.privacy.section5.title' | translate }}</h2>
        <p class="page-section-content" [innerHTML]="'pages.privacy.section5.content' | translate"></p>

        <h2 class="page-section-title">{{ 'pages.privacy.section6.title' | translate }}</h2>
        <p class="page-section-content">{{ 'pages.privacy.section6.content' | translate }}</p>

        <h2 class="page-section-title">{{ 'pages.privacy.section7.title' | translate }}</h2>
        <p class="page-section-content">{{ 'pages.privacy.section7.content' | translate }}</p>

        <h2 class="page-section-title">{{ 'pages.privacy.section8.title' | translate }}</h2>
        <p class="page-section-content">
          {{ 'pages.privacy.section8.content' | translate }}
        </p>

        <p class="page-footer-text-right">{{ 'pages.privacy.last_updated' | translate }}</p>
      </div>
    </div>
  `,
  styleUrl: './privacy.component.css'
})
export class PrivacyComponent {}
