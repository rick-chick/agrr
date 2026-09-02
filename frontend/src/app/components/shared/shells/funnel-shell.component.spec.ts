import { Component } from '@angular/core';
import { provideRouter } from '@angular/router';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { describe, it, expect, beforeEach } from 'vitest';
import ja from '../../../../assets/i18n/ja.json';
import { FunnelShellComponent } from './funnel-shell.component';
import { WizardProgressPattern } from '../patterns/wizard-progress.pattern';

@Component({
  standalone: true,
  imports: [FunnelShellComponent, WizardProgressPattern],
  template: `
    <app-funnel-shell variant="wizard" titleKey="entrySchedule.title" titleIcon="📅">
      <app-wizard-progress ngProjectAs="[wizardProgress]" [steps]="steps" />
      <section class="content-card">body</section>
    </app-funnel-shell>
  `,
})
class WizardShellHostComponent {
  steps = [
    { labelKey: 'entrySchedule.steps.farm', status: 'active' as const },
    { labelKey: 'entrySchedule.steps.crop', status: 'pending' as const },
  ];
}

describe('FunnelShellComponent', () => {
  let fixture: ComponentFixture<FunnelShellComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [FunnelShellComponent, WizardShellHostComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])],
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('ja', ja as TranslationObject, true);
    translate.use('ja');

    fixture = TestBed.createComponent(FunnelShellComponent);
    fixture.componentInstance.variant = 'hub';
    fixture.componentInstance.titleKey = 'entrySchedule.title';
    fixture.componentInstance.titleIcon = '📅';
  });

  it('renders h1 before description paragraph in hub variant', async () => {
    fixture.componentInstance.descriptionKey = 'pages.entry_schedule.description';
    fixture.detectChanges();
    await fixture.whenStable();

    const header = fixture.nativeElement.querySelector('.funnel-shell-header');
    const children = Array.from(header.children as HTMLCollection) as HTMLElement[];
    const h1Index = children.findIndex((el) => el.tagName === 'H1');
    const descIndex = children.findIndex((el) => el.classList.contains('funnel-shell-description'));
    expect(h1Index).toBeGreaterThanOrEqual(0);
    expect(descIndex).toBeGreaterThan(h1Index);
  });

  it('does not apply title ellipsis overflow when descriptionKey is set', async () => {
    fixture.componentInstance.descriptionKey = 'pages.entry_schedule.description';
    fixture.detectChanges();
    await fixture.whenStable();

    const titleText = fixture.nativeElement.querySelector('.funnel-shell-title .title-text') as HTMLElement;
    const style = getComputedStyle(titleText);
    expect(style.overflow).not.toBe('hidden');
    expect(style.textOverflow).not.toBe('ellipsis');
  });

  it('projects wizard progress into header via wizardProgress attribute', async () => {
    const hostFixture = TestBed.createComponent(WizardShellHostComponent);
    hostFixture.detectChanges();
    await hostFixture.whenStable();

    const root = hostFixture.nativeElement as HTMLElement;
    const header = root.querySelector('.funnel-shell-header--wizard');
    const bodyProgress = root.querySelector('.funnel-shell-body [data-testid="wizard-progress"]');
    const headerProgress = header?.querySelector('[data-testid="wizard-progress"]');
    expect(header).toBeTruthy();
    expect(headerProgress ?? bodyProgress).toBeTruthy();
    expect(headerProgress).toBeTruthy();
    expect(hostFixture.nativeElement.querySelector('.funnel-shell-body .content-card')).toBeTruthy();
  });
});
