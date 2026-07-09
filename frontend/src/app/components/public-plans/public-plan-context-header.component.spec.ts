import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { PublicPlanContextHeaderComponent } from './public-plan-context-header.component';

describe('PublicPlanContextHeaderComponent', () => {
  let fixture: ComponentFixture<PublicPlanContextHeaderComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PublicPlanContextHeaderComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(PublicPlanContextHeaderComponent);
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      'public_plans.breadcrumb_root': 'Free crop plan',
      'public_plans.steps.crop': 'Crop'
    });
    translate.setDefaultLang('en');
    translate.use('en');
  });

  it('renders breadcrumb crumbs with a back link to the wizard start', () => {
    fixture.componentRef.setInput('crumbs', [
      { labelKey: 'public_plans.breadcrumb_root', routerLink: ['/public-plans/new'] },
      { labelKey: 'public_plans.steps.crop' }
    ]);
    fixture.detectChanges();

    const backLink = fixture.nativeElement.querySelector(
      'a.master-context-header__back'
    ) as HTMLAnchorElement;
    expect(backLink).toBeTruthy();
    expect(backLink.getAttribute('href')).toBe('/public-plans/new');
    expect(backLink.textContent?.trim()).toBe('Free crop plan');

    const current = fixture.nativeElement.querySelector('[aria-current="page"]');
    expect(current?.textContent?.trim()).toBe('Crop');
  });
});
