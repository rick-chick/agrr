import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { of, Subject, throwError } from 'rxjs';
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
        listEmpty: {
          noCrops: {
            title: 'No candidate crops',
            description: 'This farm has no crops in the entry schedule yet.',
            hint: 'Set up crop master data to add candidates.',
            action: 'Set up crops',
          },
          allIneligible: {
            title: 'No crops in season now',
            description: 'All candidate crops are outside the planting window.',
            hint: 'Try another farm or review crop schedules in detail.',
            action: 'Review crop master data',
          },
        },
        error: 'Could not load crops',
        retry: 'Retry',
        loadMore: 'Load more',
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

  it('renders FunnelShell structure with compact header and content card', async () => {
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.compact-header-card h1.compact-header-title .title-text')).toBeTruthy();
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

  it('renders list-level empty instead of crop cards when only one ineligible crop', async () => {
    await selectFarmAndShowCrops([
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

    expect(fixture.nativeElement.querySelector('.es-list-empty')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.es-crop-card')).toBeNull();
  });

  it('renders no-window empty pattern for ineligible crops when eligible crops exist', async () => {
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

    const ineligibleCard = fixture.nativeElement.querySelector('.es-crop-card.ineligible') as HTMLElement;
    expect(ineligibleCard).toBeTruthy();
    expect(ineligibleCard.querySelector('.es-crop-card-empty')).toBeTruthy();
    expect(ineligibleCard.querySelector('.es-mini-chart[role="img"]')).toBeNull();
    expect(fixture.nativeElement.querySelector('.es-list-empty')).toBeNull();
  });

  it('renders list empty block when crops response is empty', async () => {
    await selectFarmAndShowCrops([]);

    const empty = fixture.nativeElement.querySelector('.es-list-empty') as HTMLElement;
    expect(empty).toBeTruthy();
    expect(empty.getAttribute('role')).toBe('status');
    expect(empty.querySelector('.es-list-empty-title')?.textContent).toContain(
      'No candidate crops',
    );
    expect(empty.querySelector('.es-list-empty-description')?.textContent).toContain(
      'no crops in the entry schedule',
    );
    expect(empty.querySelector('.es-list-empty-hint')?.textContent).toContain(
      'Set up crop master data',
    );
    expect(empty.querySelector('.es-list-empty-action')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.es-crop-grid')).toBeNull();
  });

  it('renders list empty block when all crops are ineligible', async () => {
    await selectFarmAndShowCrops([
      {
        id: 20,
        name: 'Carrot',
        eligible: false,
        sowing_summary: { start_date: '2026-03-01', end_date: '2026-04-15' },
        transplant_summary: null,
        reason_summary: 'Out of season',
        labels: { sowing: 'Sow', transplanting: 'Transplant' },
      },
      {
        id: 21,
        name: 'Spinach',
        eligible: false,
        sowing_summary: null,
        transplant_summary: null,
        reason_summary: 'Too cold',
        labels: { sowing: 'Sow', transplanting: 'Transplant' },
      },
    ]);

    const empty = fixture.nativeElement.querySelector('.es-list-empty') as HTMLElement;
    expect(empty).toBeTruthy();
    expect(empty.querySelector('.es-list-empty-title')?.textContent).toContain(
      'No crops in season now',
    );
    expect(empty.querySelector('.es-list-empty-description')?.textContent).toContain(
      'outside the planting window',
    );
    expect(fixture.nativeElement.querySelector('.es-crop-grid')).toBeNull();
    expect(fixture.nativeElement.querySelector('.es-crop-card')).toBeNull();
  });

  it('distinguishes loading, error, and list empty states visually', async () => {
    const cropsSubject = new Subject<{
      farm: Farm;
      crops: EntryScheduleCropListItem[];
      prediction: Record<string, unknown>;
      meta: { has_more: boolean; next_cursor: null };
    }>();
    getEntryScheduleCrops.mockReturnValue(cropsSubject.asObservable());

    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const farmCards = fixture.nativeElement.querySelectorAll(
      '.enhanced-selection-card',
    ) as NodeListOf<HTMLElement>;
    farmCards[0].click();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.master-loading')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.error-message')).toBeNull();
    expect(fixture.nativeElement.querySelector('.es-list-empty')).toBeNull();

    cropsSubject.next({
      farm: farms[0],
      crops: [],
      prediction: {},
      meta: { has_more: false, next_cursor: null },
    });
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.es-list-empty')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.error-message')).toBeNull();
    expect(fixture.nativeElement.querySelector('.master-loading')).toBeNull();

    getEntryScheduleCrops.mockReturnValue(throwError(() => new Error('network')));
    fixture.componentInstance.loadCrops(false);
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.error-message')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.es-list-empty')).toBeNull();
    expect(fixture.nativeElement.querySelector('.master-loading')).toBeNull();
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

  it('auto-selects and loads crops when the user has a single farm', async () => {
    const gateway = TestBed.inject(ENTRY_SCHEDULE_GATEWAY) as unknown as {
      getEntryScheduleFarms: ReturnType<typeof vi.fn>;
    };
    gateway.getEntryScheduleFarms.mockReturnValue(of([farms[0]]));

    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(getEntryScheduleCrops).toHaveBeenCalledWith(1, expect.objectContaining({ limit: 20 }));
    expect(fixture.nativeElement.querySelectorAll('.enhanced-selection-card').length).toBe(1);
    expect(
      (fixture.nativeElement.querySelector('.enhanced-selection-card') as HTMLElement).classList.contains(
        'active',
      ),
    ).toBe(true);
    expect(fixture.nativeElement.querySelector('.placeholder-block')).toBeNull();
  });

  it('does not show list empty when ineligible crops may exist on later pages', async () => {
    getEntryScheduleCrops.mockReturnValue(
      of({
        farm: farms[0],
        crops: [
          {
            id: 30,
            name: 'Carrot',
            eligible: false,
            sowing_summary: null,
            transplant_summary: null,
            reason_summary: 'Out of season',
            labels: { sowing: 'Sow', transplanting: 'Transplant' },
          },
        ],
        prediction: { chart_calendar_year: 2026 },
        meta: { has_more: true, next_cursor: 'page-2' },
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

    expect(fixture.nativeElement.querySelector('.es-list-empty')).toBeNull();
    expect(fixture.nativeElement.querySelector('.es-crop-card.ineligible')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('button.btn.btn-secondary')?.textContent).toContain(
      'Load more',
    );
    expect(fixture.componentInstance.listEmptyKind()).toBeNull();
  });

  it('appends crops when load more is clicked', async () => {
    const pageOneCrop: EntryScheduleCropListItem = {
      id: 40,
      name: 'Tomato',
      eligible: true,
      sowing_summary: { start_date: '2026-03-01', end_date: '2026-04-15' },
      transplant_summary: null,
      reason_summary: 'OK',
      labels: { sowing: 'Sow', transplanting: 'Transplant' },
    };
    const pageTwoCrop: EntryScheduleCropListItem = {
      id: 41,
      name: 'Cucumber',
      eligible: true,
      sowing_summary: { start_date: '2026-05-01', end_date: '2026-06-01' },
      transplant_summary: null,
      reason_summary: 'OK',
      labels: { sowing: 'Sow', transplanting: 'Transplant' },
    };

    getEntryScheduleCrops
      .mockReturnValueOnce(
        of({
          farm: farms[0],
          crops: [pageOneCrop],
          prediction: { chart_calendar_year: 2026 },
          meta: { has_more: true, next_cursor: 'page-2' },
        }),
      )
      .mockReturnValueOnce(
        of({
          farm: farms[0],
          crops: [pageTwoCrop],
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

    expect(fixture.nativeElement.querySelectorAll('.es-crop-card').length).toBe(1);

    const loadMoreButton = fixture.nativeElement.querySelector(
      'button.btn.btn-secondary',
    ) as HTMLButtonElement;
    loadMoreButton.click();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(getEntryScheduleCrops).toHaveBeenLastCalledWith(
      1,
      expect.objectContaining({ limit: 20, cursor: 'page-2' }),
    );
    const cropNames = Array.from(
      fixture.nativeElement.querySelectorAll('.es-crop-name'),
    ).map((node: Element) => node.textContent?.trim());
    expect(cropNames).toEqual(['Tomato', 'Cucumber']);
    expect(fixture.nativeElement.querySelector('button.btn.btn-secondary')).toBeNull();
  });
});
