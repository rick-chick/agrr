import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { PlanPlanContextHeaderComponent } from './plan-plan-context-header.component';

describe('PlanPlanContextHeaderComponent', () => {
  let fixture: ComponentFixture<PlanPlanContextHeaderComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanPlanContextHeaderComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(PlanPlanContextHeaderComponent);
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      'plans.show.back_to_list': 'Back to plans',
      'plans.show.open_work': 'Work hub',
      'plans.show.title': '{{name}} plan'
    });
    translate.setDefaultLang('en');
    translate.use('en');
  });

  it('renders only the back link while plan name is loading', () => {
    fixture.componentRef.setInput('planId', 42);
    fixture.componentRef.setInput('pageTitleKey', 'plans.show.title');
    fixture.componentRef.setInput('planName', null);
    fixture.detectChanges();

    const backLink = fixture.nativeElement.querySelector(
      'a.plan-context-header__back'
    ) as HTMLAnchorElement;
    expect(backLink).toBeTruthy();
    expect(backLink.getAttribute('href')).toBe('/plans');
    expect(backLink.textContent?.trim()).toBe('Back to plans');

    expect(fixture.nativeElement.querySelector('a.plan-context-header__forward')).toBeNull();
    expect(fixture.nativeElement.querySelector('app-plan-detail-context-nav')).toBeNull();
  });

  it('renders work-hub forward link and context nav when plan name is loaded', () => {
    fixture.componentRef.setInput('planId', 42);
    fixture.componentRef.setInput('pageTitleKey', 'plans.show.title');
    fixture.componentRef.setInput('planName', 'Tomato 2026');
    fixture.detectChanges();

    const backLink = fixture.nativeElement.querySelector(
      'a.plan-context-header__back'
    ) as HTMLAnchorElement;
    expect(backLink.getAttribute('href')).toBe('/plans');

    const forwardLink = fixture.nativeElement.querySelector(
      'a.plan-context-header__forward'
    ) as HTMLAnchorElement;
    expect(forwardLink).toBeTruthy();
    expect(forwardLink.getAttribute('href')).toBe('/plans/42/work');
    expect(forwardLink.textContent?.trim()).toBe('Work hub');

    expect(fixture.nativeElement.querySelector('app-plan-detail-context-nav')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Tomato 2026');
  });
});
