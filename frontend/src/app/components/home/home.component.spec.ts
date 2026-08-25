import { Component, Input } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { HomeComponent } from './home.component';
import { LOAD_HOME_DEMO_GANTT_SHELL } from './home-demo-gantt-shell.loader';

@Component({
  selector: 'app-plan-gantt-climate-shell',
  standalone: true,
  template: ''
})
class StubPlanGanttClimateShellComponent {
  @Input() data: unknown;
  @Input() planType: 'private' | 'public' | 'demo' = 'demo';
}

describe('HomeComponent', () => {
  let fixture: ComponentFixture<HomeComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [HomeComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        {
          provide: LOAD_HOME_DEMO_GANTT_SHELL,
          useValue: () => Promise.resolve(StubPlanGanttClimateShellComponent)
        }
      ]
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
