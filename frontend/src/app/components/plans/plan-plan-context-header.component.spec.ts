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
      'plans.show.title': '{{name}} plan',
      'plans.work.page_title': 'Work log — {{name}}'
    });
    translate.setDefaultLang('en');
    translate.use('en');
  });

  it('renders no crumbs or context nav while plan name is loading', () => {
    fixture.componentRef.setInput('planId', 42);
    fixture.componentRef.setInput('pageTitleKey', 'plans.show.title');
    fixture.componentRef.setInput('planName', null);
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-context-header__crumbs')).toBeNull();
    expect(fixture.nativeElement.querySelector('app-plan-detail-context-nav')).toBeNull();
  });

  it('renders plan identity and unified context nav without redundant crumbs', () => {
    fixture.componentRef.setInput('planId', 42);
    fixture.componentRef.setInput('pageTitleKey', 'plans.show.title');
    fixture.componentRef.setInput('planName', 'Tomato 2026');
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-context-header__crumbs')).toBeNull();
    expect(fixture.nativeElement.querySelector('app-plan-detail-context-nav')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Tomato 2026');
  });
});
