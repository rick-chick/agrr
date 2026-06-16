import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';

import { TermsComponent } from './terms.component';

const termsTranslation = {
  pages: {
    terms: {
      heading: 'Terms of Service',
      intro: 'Intro',
      article1: { title: '1', content: 'Content' },
      article2: { title: '2', intro: 'Intro', items: [] },
      article3: { title: '3', content: 'Content' },
      article4: { title: '4', intro: 'Intro', items: [] },
      article5: { title: '5', content: 'Content' },
      article6: { title: '6', intro: 'Intro', items: [], note: 'Note' },
      article7: { title: '7', content: 'Content' },
      article8: { title: '8', content: 'Content' },
      article9: { title: '9', content: 'Content' },
      article10: {
        title: 'Article 10 (Contact)',
        content_html: 'For inquiries regarding these Terms, please contact us via {{contact_link}}.',
        contact_link_text: 'Contact Page'
      },
      effective_date: 'Effective date'
    }
  }
};

describe('TermsComponent', () => {
  let fixture: ComponentFixture<TermsComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TermsComponent, TranslateModule.forRoot()]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', termsTranslation, true);
    translate.use('en');

    fixture = TestBed.createComponent(TermsComponent);
    fixture.detectChanges();
  });

  it('renders article 10 contact link instead of raw {{contact_link}} placeholder', () => {
    const root = fixture.nativeElement as HTMLElement;
    const article10 = Array.from(root.querySelectorAll('.page-section-content')).find((el) =>
      el.textContent?.includes('For inquiries regarding these Terms')
    );

    expect(article10).not.toBeUndefined();
    const contactLink = article10?.querySelector('a[href="/contact"]');
    expect(contactLink).not.toBeNull();
    expect(contactLink?.textContent).toContain('Contact Page');
    expect(article10?.textContent).not.toContain('{{contact_link}}');
  });
});
