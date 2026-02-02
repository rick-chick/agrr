import { Component } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { RouterLink } from '@angular/router';

@Component({
  selector: 'app-about',
  standalone: true,
  imports: [TranslateModule, RouterLink],
  template: `
    <div class="page-content-container">
      <div class="page-header">
        <h1 class="page-title">{{ 'pages.about.heading' | translate }}</h1>
      </div>
      
      <div class="page-content">
        <section class="page-section">
          <h2 class="page-section-title">{{ 'pages.about.what_is.title' | translate }}</h2>
          <p class="page-section-content">{{ 'pages.about.what_is.content' | translate }}</p>
        </section>

        <section class="page-section">
          <h2 class="page-section-title">{{ 'pages.about.features_section.title' | translate }}</h2>
          <div class="feature-grid">
            @for (item of ('pages.about.features_section.items' | translate); track item.title) {
              <div class="feature-card">
                <h3 class="feature-card-title">{{ item.icon }} {{ item.title }}</h3>
                <p class="feature-card-content">{{ item.description }}</p>
              </div>
            }
          </div>
        </section>

        <section class="page-section">
          <h2 class="page-section-title">{{ 'pages.about.characteristics.title' | translate }}</h2>
          <p class="page-section-content">{{ 'pages.about.characteristics.intro' | translate }}</p>
          <ul class="page-list">
            @for (item of ('pages.about.characteristics.items' | translate); track item) {
              <li [innerHTML]="item"></li>
            }
          </ul>
        </section>

        <section class="page-section">
          <h2 class="page-section-title">{{ 'pages.about.development.title' | translate }}</h2>
          <p class="page-section-content">{{ 'pages.about.development.paragraph1' | translate }}</p>
          <p class="page-section-content">{{ 'pages.about.development.paragraph2' | translate }}</p>
        </section>

        <section class="page-section" id="operator-info">
          <h2 class="page-section-title">{{ 'pages.about.operator.title' | translate }}</h2>
          <ul class="page-list">
            <li>{{ 'pages.about.operator.operator_name' | translate }}</li>
            <li>{{ 'pages.about.operator.location' | translate }}</li>
            <li>{{ 'pages.about.operator.initiative' | translate }}</li>
            <li>
              {{ 'pages.about.operator.contact' | translate: { 
                  email_link: 'support@agrr.net', 
                  contact_link: ('pages.about.operator.contact_form' | translate) 
                } }}
            </li>
            <li>
              {{ 'pages.about.operator.ads_notice' | translate: { 
                  privacy_link: ('pages.about.operator.privacy_link_text' | translate) 
                } }}
            </li>
          </ul>
          <p class="page-section-content">{{ 'pages.about.operator.sources_and_updates' | translate }}</p>
        </section>

        <section class="highlight-box">
          <h2 class="highlight-box-title">{{ 'pages.about.contact_section.title' | translate }}</h2>
          <p class="highlight-box-content">{{ 'pages.about.contact_section.message' | translate }}</p>
          <a routerLink="/contact" class="highlight-box-button">{{ 'pages.about.contact_section.button_text' | translate }}</a>
        </section>

        <p class="page-footer-text">{{ 'pages.about.copyright' | translate }}</p>
      </div>
    </div>
  `,
  styleUrls: ['./about.component.css']
})
export class AboutComponent {}
