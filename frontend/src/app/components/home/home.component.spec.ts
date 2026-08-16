import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, expect, it, beforeEach } from 'vitest';
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
      'home.index.hero.title': 'Smart farming',
      'home.index.hero.subtitle_html': 'Subtitle',
      'home.index.hero.cta_scroll_demo': 'Try demo',
      'home.index.hero.cta_entry_schedule': 'Planting schedule guide',
      'home.index.features.title': 'Features',
      'home.index.features.subtitle': 'Subtitle',
      'home.index.features.growth_prediction.title': 'Growth',
      'home.index.features.growth_prediction.description': 'Desc',
      'home.index.features.weather.title': 'Weather',
      'home.index.features.weather.description': 'Desc',
      'home.index.features.optimization.title': 'Opt',
      'home.index.features.optimization.description': 'Desc',
      'home.index.hero.cta_footer_link': 'Create plan'
    });
    translate.setDefaultLang('en');
    translate.use('en');
  });

  it('shows secondary CTA linking to entry schedule in hero actions', () => {
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector(
      'a.hero-entry-schedule-link'
    ) as HTMLAnchorElement;
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toBe('/entry-schedule');
    expect(link.textContent?.trim()).toBe('Planting schedule guide');
  });
});
