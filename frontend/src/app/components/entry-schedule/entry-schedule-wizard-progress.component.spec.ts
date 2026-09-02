import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { describe, it, expect, beforeEach } from 'vitest';
import ja from '../../../assets/i18n/ja.json';
import { EntryScheduleWizardProgressComponent } from './entry-schedule-wizard-progress.component';

describe('EntryScheduleWizardProgressComponent', () => {
  let fixture: ComponentFixture<EntryScheduleWizardProgressComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [EntryScheduleWizardProgressComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])],
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('ja', ja as TranslationObject, true);
    translate.use('ja');

    fixture = TestBed.createComponent(EntryScheduleWizardProgressComponent);
  });

  it('renders crop step active with farm step link when on crop step', () => {
    fixture.componentInstance.activeStep = 'crop';
    fixture.detectChanges();

    const farmLink = fixture.nativeElement.querySelector('a.step-label-link') as HTMLAnchorElement;
    expect(farmLink?.getAttribute('href')).toBe('/entry-schedule');
    expect(fixture.nativeElement.querySelector('.compact-step.active .step-label')?.textContent?.trim()).toBe(
      '作物',
    );
  });

  it('renders farm step active when on farm step', () => {
    fixture.componentInstance.activeStep = 'farm';
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('a.step-label-link')).toBeNull();
    expect(fixture.nativeElement.querySelector('.compact-step.active .step-label')?.textContent?.trim()).toBe(
      '農場',
    );
  });
});
