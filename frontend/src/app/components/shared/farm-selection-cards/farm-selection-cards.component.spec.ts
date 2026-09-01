import { ComponentFixture, TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { FarmSelectionCardsComponent } from './farm-selection-cards.component';
import type { Farm } from '../../../domain/farms/farm';

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

  it('applies enhanced-grid card layout styles from public-plan.component.css', () => {
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('[data-testid="farm-selection-cards"]')).toBeTruthy();

    const grid = fixture.nativeElement.querySelector('.enhanced-grid') as HTMLElement;
    expect(grid).toBeTruthy();
    expect(getComputedStyle(grid).display).toBe('grid');

    const card = fixture.nativeElement.querySelector('.enhanced-selection-card') as HTMLElement;
    expect(getComputedStyle(card).borderRadius).not.toBe('0px');
  });
});
