import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach } from 'vitest';
import { WizardProgressPattern } from './wizard-progress.pattern';

describe('WizardProgressPattern', () => {
  let fixture: ComponentFixture<WizardProgressPattern>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [WizardProgressPattern, TranslateModule.forRoot()],
      providers: [provideRouter([])],
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      'steps.one': 'Step one',
      'steps.two': 'Step two',
    });
    translate.setDefaultLang('en');
    translate.use('en');

    fixture = TestBed.createComponent(WizardProgressPattern);
    fixture.componentInstance.step1LabelKey = 'steps.one';
    fixture.componentInstance.step2LabelKey = 'steps.two';
  });

  it('renders step 1 active without back link', () => {
    fixture.componentInstance.activeStep = 1;
    fixture.detectChanges();

    const progress = fixture.nativeElement.querySelector('[data-testid="wizard-progress"]');
    expect(progress).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.compact-step.active .step-label')?.textContent?.trim()).toBe(
      'Step one',
    );
    expect(fixture.nativeElement.querySelector('a.step-label-link')).toBeNull();
  });

  it('renders step 2 active with optional step 1 link', () => {
    fixture.componentInstance.activeStep = 2;
    fixture.componentInstance.step1Link = '/back';
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector('a.step-label-link') as HTMLAnchorElement;
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toBe('/back');
    expect(fixture.nativeElement.querySelector('.compact-step.active .step-label')?.textContent?.trim()).toBe(
      'Step two',
    );
    expect(fixture.nativeElement.querySelector('.compact-step-divider.completed')).toBeTruthy();
  });
});
