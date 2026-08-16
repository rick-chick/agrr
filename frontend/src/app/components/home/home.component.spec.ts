import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { HomeComponent } from './home.component';

describe('HomeComponent', () => {
  let fixture: ComponentFixture<HomeComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [HomeComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(HomeComponent);
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      home: {
        index: {
          hero: {
            title: 'Hero',
            subtitle_html: 'Subtitle',
            cta_scroll_demo: 'Try demo',
            cta_entry_schedule: 'View sowing guide',
            cta_footer_link: 'Create plan'
          }
        }
      }
    });
    translate.setDefaultLang('en');
    translate.use('en');
  });

  it('shows secondary CTA linking to entry schedule', () => {
    fixture.detectChanges();
    const link = fixture.nativeElement.querySelector(
      'a.hero-entry-schedule-link'
    ) as HTMLAnchorElement;
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toBe('/entry-schedule');
    expect(link.textContent?.trim()).toBe('View sowing guide');
  });
});
