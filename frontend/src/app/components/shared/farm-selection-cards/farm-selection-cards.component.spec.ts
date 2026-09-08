import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { FarmSelectionCardsComponent } from './farm-selection-cards.component';
import type { Farm } from '../../../domain/farms/farm';

const publicPlanComponentCss = readFileSync(
  join(dirname(fileURLToPath(import.meta.url)), '../../public-plans/public-plan.component.css'),
  'utf8',
);

describe('FarmSelectionCardsComponent', () => {
  let fixture: ComponentFixture<FarmSelectionCardsComponent>;
  let component: FarmSelectionCardsComponent;

  const farms: Farm[] = [
    { id: 1, name: 'Farm A', latitude: 35, longitude: 139, region: 'jp' },
    { id: 2, name: 'Farm B', latitude: 34, longitude: 135, region: 'jp' },
  ];

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [FarmSelectionCardsComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(FarmSelectionCardsComponent);
    component = fixture.componentInstance;
    component.farms = farms;
    component.heading = 'Select a farm';
    component.headingId = 'farm-heading';
  });

  it('renders farm selection cards with labels', () => {
    fixture.detectChanges();

    const cards = fixture.nativeElement.querySelectorAll('.enhanced-selection-card');
    expect(cards.length).toBe(2);
    expect(cards[0].textContent).toContain('Farm A');
    expect(cards[1].textContent).toContain('Farm B');
    expect(fixture.nativeElement.querySelector('#farm-heading')?.textContent).toContain(
      'Select a farm',
    );
  });

  it('emits farmSelect when a card is activated', () => {
    const onSelect = vi.fn();
    component.farmSelect.subscribe(onSelect);
    fixture.detectChanges();

    const cards = fixture.nativeElement.querySelectorAll(
      '.enhanced-selection-card',
    ) as NodeListOf<HTMLElement>;
    cards[1].click();

    expect(onSelect).toHaveBeenCalledWith(farms[1]);
  });

  it('marks the selected farm card as active with aria-pressed', () => {
    component.selectedFarmId = 1;
    fixture.detectChanges();

    const cards = fixture.nativeElement.querySelectorAll(
      '.enhanced-selection-card',
    ) as NodeListOf<HTMLElement>;
    expect(cards[0].classList.contains('active')).toBe(true);
    expect(cards[0].getAttribute('aria-pressed')).toBe('true');
    expect(cards[1].getAttribute('aria-pressed')).toBe('false');
  });

  it('uses farmLabel when provided', () => {
    component.farmLabel = (farm) => `Label:${farm.name}`;
    fixture.detectChanges();

    const cards = fixture.nativeElement.querySelectorAll('.enhanced-selection-card');
    expect(cards[0].textContent).toContain('Label:Farm A');
  });

  it('exposes data-testid for E2E farm selection cards', () => {
    fixture.detectChanges();

    expect(
      fixture.nativeElement.querySelector('[data-testid="farm-selection-cards"]'),
    ).toBeTruthy();
  });

  it('applies enhanced-grid card layout styles from public-plan CSS', () => {
    fixture.detectChanges();

    const grid = fixture.nativeElement.querySelector('.enhanced-grid') as HTMLElement;
    expect(grid).toBeTruthy();
    expect(getComputedStyle(grid).display).toBe('grid');
  });

  it('applies uniform card height and single-line title ellipsis styles', () => {
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

describe('public-plan.component.css (farm selection cards)', () => {
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
