import { Component } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { ContactFormComponent } from '../../contact-form/contact-form.component';

@Component({
  selector: 'app-contact',
  standalone: true,
  imports: [TranslateModule, ContactFormComponent],
  template: `
    <div class="page-content-container">
      <h1 class="page-header">{{ 'pages.contact.heading' | translate }}</h1>
      
      <div class="page-content">
        <p class="page-section-content">{{ 'pages.contact.intro' | translate }}</p>

        <div class="info-box">
          <h2 class="info-box-title">{{ 'pages.contact.email_section_title' | translate }}</h2>
          <p class="info-box-content">{{ 'pages.contact.email_intro' | translate }}</p>
          <p class="page-section-content">
            <app-contact-form></app-contact-form>
          </p>
          <p class="text-sm text-secondary">{{ 'pages.contact.email_note' | translate }}</p>
        </div>

        <div class="info-box">
          <h2 class="info-box-title">{{ 'pages.contact.notes_title' | translate }}</h2>
          <ul class="page-list">
            @for (note of ('pages.contact.notes' | translate); track note) {
              <li>{{ note }}</li>
            }
          </ul>
        </div>

        <div class="warning-box">
          <h3 class="warning-box-title">{{ 'pages.contact.faq_title' | translate }}</h3>
          <p class="warning-box-content">{{ 'pages.contact.faq_intro' | translate }}</p>
          <ul class="warning-box-list">
            @for (item of ('pages.contact.faq_items' | translate); track item) {
              <li>{{ item }}</li>
            }
          </ul>
        </div>

        <div class="text-center mt-10">
          <p class="text-secondary">{{ 'pages.contact.footer_message' | translate }}</p>
        </div>
      </div>
    </div>
  `,
  styleUrls: ['./contact.component.css']
})
export class ContactComponent {}
