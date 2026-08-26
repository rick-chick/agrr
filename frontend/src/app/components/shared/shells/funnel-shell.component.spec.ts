import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { describe, it, expect, beforeEach } from 'vitest';
import ja from '../../../../assets/i18n/ja.json';
import { FunnelShellComponent } from './funnel-shell.component';

describe('FunnelShellComponent', () => {
  let fixture: ComponentFixture<FunnelShellComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [FunnelShellComponent, TranslateModule.forRoot()],
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

  it('projects wizard progress slot in wizard variant', () => {
    fixture.componentInstance.variant = 'wizard';
    fixture.detectChanges();

    const host = fixture.nativeElement as HTMLElement;
    expect(host.querySelector('.funnel-shell-header--wizard')).toBeTruthy();
  });
});
