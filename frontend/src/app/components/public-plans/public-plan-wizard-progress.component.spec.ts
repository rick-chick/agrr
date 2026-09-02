import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach } from 'vitest';
import { PublicPlanWizardProgressComponent } from './public-plan-wizard-progress.component';

describe('PublicPlanWizardProgressComponent', () => {
  let fixture: ComponentFixture<PublicPlanWizardProgressComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PublicPlanWizardProgressComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])],
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      'public_plans.steps.region': 'Region',
      'public_plans.steps.crop': 'Crop',
    });
    translate.setDefaultLang('en');
    translate.use('en');

    fixture = TestBed.createComponent(PublicPlanWizardProgressComponent);
  });

  it('renders region step active on step 1', () => {
    fixture.componentInstance.activeStep = 'region';
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('[data-testid="wizard-progress"]')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.compact-step.active .step-label')?.textContent?.trim()).toBe(
      'Region',
    );
  });

  it('renders crop step active with region back link on step 2', () => {
    fixture.componentInstance.activeStep = 'crop';
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector('a.step-label-link') as HTMLAnchorElement;
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toBe('/public-plans/new');
    expect(fixture.nativeElement.querySelector('.compact-step.active .step-label')?.textContent?.trim()).toBe(
      'Crop',
    );
  });
});
