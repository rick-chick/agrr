import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';

import { AboutComponent } from './about.component';

const aboutTranslation = {
  meta: {
    default: {
      title: 'AGRR',
      description: 'Agricultural planning support',
      og_description: 'Agricultural planning support'
    }
  },
  pages: {
    about: {
      heading: 'About AGRR',
      what_is: {
        title: 'What is AGRR',
        content: 'Planning support'
      },
      features_section: {
        title: 'Features',
        items: [{ icon: 'A', title: 'Plan', description: 'Make plans' }]
      },
      characteristics: {
        title: 'Characteristics',
        intro: 'Intro',
        items: ['Open data']
      },
      development: {
        title: 'Development',
        paragraph1: 'Concept',
        paragraph2: 'Approach'
      },
      operator: {
        title: 'Operator Information',
        operator_name: 'Operator: AGRR',
        location: 'Location: Japan',
        initiative: 'Initiative: community garden research',
        contact_form: 'Contact Form',
        contact_html: 'Contact: {{email_link}} (you can also use the {{contact_link}})',
        ads_notice_html:
          'Ads: This site may use cookies for ad delivery. Please see the {{privacy_link}} for details.',
        privacy_link_text: 'Privacy Policy',
        sources_and_updates: 'Sources are reviewed regularly.'
      },
      contact_section: {
        title: 'Contact',
        message: 'Send feedback',
        button_text: 'Contact us'
      },
      copyright: 'Copyright'
    }
  }
};

describe('AboutComponent', () => {
  let fixture: ComponentFixture<AboutComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [AboutComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', aboutTranslation, true);
    translate.use('en');

    fixture = TestBed.createComponent(AboutComponent);
    fixture.detectChanges();
  });

  it('renders operator contact and privacy references as accessible links', () => {
    const root = fixture.nativeElement as HTMLElement;
    const operatorInfo = root.querySelector('#operator-info');
    const emailLink = operatorInfo?.querySelector('a[href="mailto:support@agrr.net"]');
    const contactLink = operatorInfo?.querySelector('a[href="/contact"]');
    const privacyLink = operatorInfo?.querySelector('a[href="/privacy"]');

    expect(emailLink).not.toBeNull();
    expect(emailLink?.textContent).toContain('support@agrr.net');
    expect(contactLink).not.toBeNull();
    expect(contactLink?.textContent).toContain('Contact Form');
    expect(privacyLink).not.toBeNull();
    expect(privacyLink?.textContent).toContain('Privacy Policy');
    expect(operatorInfo?.textContent).not.toContain('pages.about.operator.contact_html');
    expect(operatorInfo?.textContent).not.toContain('pages.about.operator.ads_notice_html');
  });
});
