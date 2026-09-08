import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import ja from '../../../../assets/i18n/ja.json';
import { FarmSelectionCardsPattern } from './farm-selection-cards.pattern';
import { Farm } from '../../../domain/farms/farm';

const publicPlanComponentCss = readFileSync(
  join(dirname(fileURLToPath(import.meta.url)), '../../public-plans/public-plan.component.css'),
  'utf8',
);

const mockFarms: Farm[] = [
  { id: 1, name: 'Farm A', latitude: 0, longitude: 0, region: 'jp' },
  { id: 2, name: 'Farm B', latitude: 0, longitude: 0, region: 'jp' },
];

describe('FarmSelectionCardsPattern', () => {
  let fixture: ComponentFixture<FarmSelectionCardsPattern>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [FarmSelectionCardsPattern, TranslateModule.forRoot()],
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('ja', ja as TranslationObject, true);
    translate.use('ja');

    fixture = TestBed.createComponent(FarmSelectionCardsPattern);
  });

  it('renders loading state', () => {
    fixture.componentInstance.state = 'loading';
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('[data-testid="farm-selection-cards"] .master-loading')).toBeTruthy();
  });

  it('renders empty state', () => {
    fixture.componentInstance.state = 'empty';
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('[data-testid="farm-selection-cards"] .farm-selection-empty')).toBeTruthy();
  });

  it('renders error state with retry output', () => {
    fixture.componentInstance.state = 'error';
    fixture.componentInstance.errorKey = 'entrySchedule.error';
    const retrySpy = vi.fn();
    fixture.componentInstance.retry.subscribe(retrySpy);
    fixture.detectChanges();
    fixture.nativeElement.querySelector('button')?.click();
    expect(retrySpy).toHaveBeenCalled();
  });

  it('renders farm cards and emits farmSelect on click', () => {
    fixture.componentInstance.state = 'ready';
    fixture.componentInstance.farms = mockFarms;
    fixture.componentInstance.selectedFarmId = 1;
    const selectSpy = vi.fn();
    fixture.componentInstance.farmSelect.subscribe(selectSpy);
    fixture.detectChanges();

    const cards = fixture.nativeElement.querySelectorAll('.enhanced-selection-card');
    expect(cards.length).toBe(2);
    cards[1].click();
    expect(selectSpy).toHaveBeenCalledWith(mockFarms[1]);
  });

  it('marks selected farm card as active', () => {
    fixture.componentInstance.state = 'ready';
    fixture.componentInstance.farms = mockFarms;
    fixture.componentInstance.selectedFarmId = 2;
    fixture.detectChanges();

    const active = fixture.nativeElement.querySelector('.enhanced-selection-card.active');
    expect(active?.textContent).toContain('Farm B');
  });

  it('applies uniform card height and single-line title ellipsis styles in ready state', () => {
    fixture.componentInstance.state = 'ready';
    fixture.componentInstance.farms = mockFarms;
    fixture.detectChanges();

    const card = fixture.nativeElement.querySelector('.enhanced-selection-card') as HTMLElement;
    const title = fixture.nativeElement.querySelector('.enhanced-card-title') as HTMLElement;
    expect(card).toBeTruthy();
    expect(title).toBeTruthy();
    expect(parseFloat(getComputedStyle(card).minHeight)).toBeGreaterThan(0);
    expect(getComputedStyle(title).whiteSpace).toBe('nowrap');
    expect(getComputedStyle(title).overflow).toBe('hidden');
    expect(getComputedStyle(title).textOverflow).toBe('ellipsis');
  });
});

describe('public-plan.component.css (farm selection cards pattern)', () => {
  it('defines uniform min-height and single-line ellipsis for enhanced selection cards', () => {
    expect(publicPlanComponentCss).toMatch(
      /\.enhanced-selection-card\s*\{[\s\S]*min-height:\s*[\d.]+rem/,
    );
    expect(publicPlanComponentCss).toMatch(
      /\.enhanced-card-title\s*\{[\s\S]*white-space:\s*nowrap/,
    );
    expect(publicPlanComponentCss).toMatch(
      /\.enhanced-card-title\s*\{[\s\S]*text-overflow:\s*ellipsis/,
    );
  });
});
