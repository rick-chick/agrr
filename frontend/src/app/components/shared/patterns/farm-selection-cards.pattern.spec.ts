import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import ja from '../../../../assets/i18n/ja.json';
import { FarmSelectionCardsPattern } from './farm-selection-cards.pattern';
import { Farm } from '../../../domain/farms/farm';

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
});
