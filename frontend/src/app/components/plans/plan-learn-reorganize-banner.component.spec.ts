import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { PlanLearnReorganizeBannerComponent } from './plan-learn-reorganize-banner.component';

describe('PlanLearnReorganizeBannerComponent', () => {
  let fixture: ComponentFixture<PlanLearnReorganizeBannerComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanLearnReorganizeBannerComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.learn.reorganize.placement.message': 'Verify placement after master update',
        'plans.learn.reorganize.placement.hint': 'Drag cultivations on the Gantt to adjust.',
        'plans.learn.reorganize.optimizing.message': 'Re-optimization in progress',
        'plans.learn.reorganize.optimizing.hint': 'Wait for placement optimization to finish.',
        'plans.learn.reorganize.return_to_learn': 'Return to learning screen'
      },
      true
    );

    fixture = TestBed.createComponent(PlanLearnReorganizeBannerComponent);
    fixture.componentInstance.planId = 7;
  });

  it('renders nothing when not visible', () => {
    fixture.componentInstance.visible = false;
    fixture.componentInstance.context = 'placement';
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent?.trim()).toBe('');
  });

  it('renders progress strip and return-to-learn link during placement reorganize', () => {
    fixture.componentInstance.visible = true;
    fixture.componentInstance.context = 'placement';
    fixture.detectChanges();

    expect(
      fixture.nativeElement.querySelector('app-plan-learn-loop-progress-strip')
    ).not.toBeNull();
    const link = fixture.nativeElement.querySelector('a.learn-reorganize-banner__learn-link');
    expect(link).not.toBeNull();
    expect(link.getAttribute('href')).toBe('/plans/7/learn');
    expect(link.textContent).toContain('Return to learning screen');
    expect(fixture.nativeElement.textContent).toContain('Verify placement after master update');
  });

  it('renders optimizing context message during re-optimization', () => {
    fixture.componentInstance.visible = true;
    fixture.componentInstance.context = 'optimizing';
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('Re-optimization in progress');
    expect(fixture.nativeElement.textContent).toContain('Wait for placement optimization');
  });
});
