import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { of } from 'rxjs';
import { vi } from 'vitest';
import { EntryScheduleListComponent } from './entry-schedule-list.component';
import { ENTRY_SCHEDULE_GATEWAY } from '../../usecase/entry-schedule/entry-schedule-gateway';
import type { Farm } from '../../domain/farms/farm';
import type { EntryScheduleCropListItem } from '../../domain/entry-schedule/entry-schedule';

describe('EntryScheduleListComponent', () => {
  let fixture: ComponentFixture<EntryScheduleListComponent>;
  let translate: TranslateService;
  let getEntryScheduleCrops: ReturnType<typeof vi.fn>;

  const farms: Farm[] = [
    { id: 1, name: 'Farm A', latitude: 35, longitude: 139, region: 'jp' },
    { id: 2, name: 'Farm B', latitude: 34, longitude: 135, region: 'jp' },
  ];

  beforeEach(async () => {
    getEntryScheduleCrops = vi.fn(() =>
      of({
        farm: farms[0],
        crops: [],
        prediction: {},
        meta: { has_more: false, next_cursor: null },
      }),
    );

    await TestBed.configureTestingModule({
      imports: [EntryScheduleListComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        {
          provide: ENTRY_SCHEDULE_GATEWAY,
          useValue: {
            getEntryScheduleFarms: vi.fn(() => of(farms)),
            getEntryScheduleCrops,
          },
        },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(EntryScheduleListComponent);
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      entrySchedule: {
        title: 'Entry schedule',
        selectFarm: 'Select a farm',
        loading: 'Loading…',
        blockSelectFarm: 'Select a farm to view crops',
        eligibleYes: 'Suitable',
        eligibleNo: 'Not suitable',
        table: { detail: 'Detail' },
        viz: {
          noWindowTitle: 'No planting window',
          noWindowHint: 'Open the detail view for schedule notes and reasons.',
          listChartIntro: 'Candidate window overview',
        },
      },
      pages: {
        entry_schedule: {
          description: 'Browse crop planting windows by farm',
        },
      },
    });
    translate.setDefaultLang('en');
    translate.use('en');
  });

  it('renders FunnelShell with farm selection cards', async () => {
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-funnel-shell')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('[data-testid="farm-selection-cards"]')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('section.content-card')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('#entry-farm-select')).toBeNull();
  });

  it('renders farm selection as enhanced selection cards', async () => {
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const cards = fixture.nativeElement.querySelectorAll('.enhanced-selection-card');
    expect(cards.length).toBe(2);
    expect(cards[0].textContent).toContain('Farm A');
    expect(cards[1].textContent).toContain('Farm B');
  });

  it('loads crops when a farm card is selected', async () => {
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const cards = fixture.nativeElement.querySelectorAll(
      '.enhanced-selection-card',
    ) as NodeListOf<HTMLElement>;
    cards[0].click();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(getEntryScheduleCrops).toHaveBeenCalledWith(1, expect.objectContaining({ limit: 20 }));
    expect(cards[0].classList.contains('active')).toBe(true);
  });

  async function selectFarmAndShowCrops(crops: EntryScheduleCropListItem[]): Promise<void> {
    getEntryScheduleCrops.mockReturnValue(
      of({
        farm: farms[0],
        crops,
        prediction: { chart_calendar_year: 2026 },
        meta: { has_more: false, next_cursor: null },
      }),
    );

    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const farmCards = fixture.nativeElement.querySelectorAll(
      '.enhanced-selection-card',
    ) as NodeListOf<HTMLElement>;
    farmCards[0].click();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  it('renders paved-road empty pattern when crop has no planting windows', async () => {
    await selectFarmAndShowCrops([
      {
        id: 10,
        name: 'Carrot',
        eligible: true,
        sowing_summary: null,
        transplant_summary: null,
        reason_summary: 'No window',
        labels: { sowing: 'Sow', transplanting: 'Transplant' },
      },
    ]);

    const card = fixture.nativeElement.querySelector('.es-crop-card') as HTMLElement;
    const empty = card.querySelector('.es-crop-card-empty') as HTMLElement;

    expect(empty).toBeTruthy();
    expect(empty.getAttribute('role')).toBe('status');
    expect(empty.querySelector('.es-crop-card-empty-icon')).toBeTruthy();
    expect(empty.querySelector('.es-crop-card-empty-message')?.textContent).toContain(
      'No planting window',
    );
    expect(empty.querySelector('.es-crop-card-empty-hint')?.textContent).toContain(
      'Open the detail view',
    );
    expect(card.querySelector('.es-mini-chart[role="img"]')).toBeNull();
    expect(card.querySelector('.es-link-detail')).toBeTruthy();
  });

  it('renders no-window empty pattern for ineligible crops independently', async () => {
    await selectFarmAndShowCrops([
      {
        id: 12,
        name: 'Tomato',
        eligible: true,
        sowing_summary: { start_date: '2026-03-01', end_date: '2026-04-15' },
        transplant_summary: null,
        reason_summary: 'OK',
        labels: { sowing: 'Sow', transplanting: 'Transplant' },
      },
      {
        id: 11,
        name: 'Spinach',
        eligible: false,
        sowing_summary: null,
        transplant_summary: null,
        reason_summary: 'Out of season',
        labels: { sowing: 'Sow', transplanting: 'Transplant' },
      },
    ]);

    const card = fixture.nativeElement.querySelector('.es-crop-card.ineligible') as HTMLElement;
    expect(card).toBeTruthy();
    expect(card.querySelector('.es-crop-card-empty')).toBeTruthy();
    expect(card.querySelector('.es-mini-chart[role="img"]')).toBeNull();
  });

  it('renders mini chart when crop has planting windows', async () => {
    await selectFarmAndShowCrops([
      {
        id: 12,
        name: 'Tomato',
        eligible: true,
        sowing_summary: { start_date: '2026-03-01', end_date: '2026-04-15' },
        transplant_summary: null,
        reason_summary: 'OK',
        labels: { sowing: 'Sow', transplanting: 'Transplant' },
      },
    ]);

    const card = fixture.nativeElement.querySelector('.es-crop-card') as HTMLElement;
    expect(card.querySelector('.es-crop-card-empty')).toBeNull();
    expect(card.querySelector('.es-mini-chart[role="img"]')).toBeTruthy();
  });
});
