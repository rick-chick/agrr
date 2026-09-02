import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { describe, it, expect, beforeEach } from 'vitest';
import ja from '../../../../assets/i18n/ja.json';
import { WizardProgressPattern } from './wizard-progress.pattern';

describe('WizardProgressPattern', () => {
  let fixture: ComponentFixture<WizardProgressPattern>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [WizardProgressPattern, TranslateModule.forRoot()],
      providers: [provideRouter([])],
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('ja', ja as TranslationObject, true);
    translate.use('ja');

    fixture = TestBed.createComponent(WizardProgressPattern);
  });

  it('renders first step active and second pending', () => {
    fixture.componentInstance.steps = [
      { labelKey: 'public_plans.steps.region', status: 'active' },
      { labelKey: 'public_plans.steps.crop', status: 'pending' },
    ];
    fixture.detectChanges();

    const root = fixture.nativeElement.querySelector('[data-testid="wizard-progress"]');
    expect(root).toBeTruthy();
    const active = fixture.nativeElement.querySelector('.compact-step.active .step-label');
    expect(active?.textContent?.trim()).toBe('地域');
    expect(fixture.nativeElement.querySelector('.compact-step-divider.completed')).toBeNull();
  });

  it('renders completed first step with router link and active second step', () => {
    fixture.componentInstance.steps = [
      {
        labelKey: 'public_plans.steps.region',
        status: 'completed',
        routerLink: '/public-plans/new',
      },
      { labelKey: 'public_plans.steps.crop', status: 'active' },
    ];
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector('a.step-label-link') as HTMLAnchorElement;
    expect(link?.getAttribute('href')).toBe('/public-plans/new');
    expect(fixture.nativeElement.querySelector('.compact-step-divider.completed')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.compact-step.active .step-label')?.textContent?.trim()).toBe(
      '作物',
    );
  });
});
