import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';

import { PrivacyComponent } from './privacy.component';

const privacyTranslation = {
  pages: {
    privacy: {
      heading: 'Privacy Policy',
      intro_html: 'Intro',
      section1: { title: '1', intro: 'Intro', items: [] },
      section2: { title: '2', intro: 'Intro', items: [] },
      section3: { title: '3', intro: 'Intro', items: [] },
      section4: { title: '4', content_html: 'Content' },
      section5: { title: '5', content_html: 'Content' },
      section6: { title: '6', content: 'Content' },
      section7: { title: '7', content: 'Content' },
      section8: {
        title: '8. Contact',
        content_html: 'For inquiries, please contact us via {{contact_link}}.',
        contact_link_text: 'Contact Page'
      },
      last_updated: 'Last updated'
    }
  }
};

describe('PrivacyComponent', () => {
  let fixture: ComponentFixture<PrivacyComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PrivacyComponent, TranslateModule.forRoot()]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', privacyTranslation, true);
    translate.use('en');

    fixture = TestBed.createComponent(PrivacyComponent);
    fixture.detectChanges();
  });

  it('renders section 8 contact link instead of raw {{contact_link}} placeholder', () => {
    const root = fixture.nativeElement as HTMLElement;
    const section8 = Array.from(root.querySelectorAll('.page-section-content')).find((el) =>
      el.textContent?.includes('For inquiries')
    );

    expect(section8).not.toBeUndefined();
    const contactLink = section8?.querySelector('a[href="/contact"]');
    expect(contactLink).not.toBeNull();
    expect(contactLink?.textContent).toContain('Contact Page');
    expect(section8?.textContent).not.toContain('{{contact_link}}');
  });
});
