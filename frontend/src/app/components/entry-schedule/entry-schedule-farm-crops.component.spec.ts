import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter, Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { of, Subject, throwError } from 'rxjs';
import { vi } from 'vitest';
import { EntryScheduleFarmCropsComponent } from './entry-schedule-farm-crops.component';
import { ENTRY_SCHEDULE_GATEWAY } from '../../usecase/entry-schedule/entry-schedule-gateway';
import { FlashMessageService } from '../../services/flash-message.service';
import type { Farm } from '../../domain/farms/farm';
import type { EntryScheduleCropListItem } from '../../domain/entry-schedule/entry-schedule';

describe('EntryScheduleFarmCropsComponent', () => {
  let fixture: ComponentFixture<EntryScheduleFarmCropsComponent>;
  let translate: TranslateService;
  let router: Router;
  let flash: { show: ReturnType<typeof vi.fn> };
  let getEntryScheduleCrops: ReturnType<typeof vi.fn>;
  let getEntryScheduleFarms: ReturnType<typeof vi.fn>;
  let farmIdParam: string | null;

  const farms: Farm[] = [
    { id: 1, name: 'Farm A', latitude: 35, longitude: 139, region: 'jp' },
    { id: 2, name: 'Farm B', latitude: 34, longitude: 135, region: 'jp' },
  ];

  beforeEach(async () => {
    farmIdParam = '1';
    getEntryScheduleCrops = vi.fn(() =>
      of({
        farm: farms[0],
        crops: [],
        prediction: {},
        meta: { has_more: false, next_cursor: null },
      }),
    );
    getEntryScheduleFarms = vi.fn(() => of(farms));
    flash = { show: vi.fn() };

    await TestBed.configureTestingModule({
      imports: [EntryScheduleFarmCropsComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        {
          provide: ActivatedRoute,
          useValue: {
            snapshot: {
              paramMap: {
                get: (key: string) => (key === 'farmId' ? farmIdParam : null),
              },
            },
          },
        },
        {
          provide: ENTRY_SCHEDULE_GATEWAY,
          useValue: {
            getEntryScheduleFarms,
            getEntryScheduleCrops,
          },
        },
        { provide: FlashMessageService, useValue: flash },
      ],
    }).compileComponents();

    router = TestBed.inject(Router);
    fixture = TestBed.createComponent(EntryScheduleFarmCropsComponent);
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      entrySchedule: {
        title: 'Entry schedule',
        selectFarm: 'Select a farm',
        loading: 'Loading…',
        invalid_farm_id: 'Invalid farm ID.',
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
        steps: {
          farm: 'Farm',
          crop: 'Crop',
        },
        summary: {
          farm: 'Selected farm',
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

  async function initComponent(): Promise<void> {
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  async function showCrops(crops: EntryScheduleCropListItem[]): Promise<void> {
    getEntryScheduleCrops.mockReturnValue(
      of({
        farm: farms[0],
        crops,
        prediction: { chart_calendar_year: 2026 },
        meta: { has_more: false, next_cursor: null },
      }),
    );
    await initComponent();
  }

  it('loads crops for the farm route param', async () => {
    await initComponent();

    expect(getEntryScheduleFarms).toHaveBeenCalled();
    expect(getEntryScheduleCrops).toHaveBeenCalledWith(1, expect.objectContaining({ limit: 20 }));
    expect(fixture.nativeElement.querySelector('.es-crop-grid')).toBeNull();
    expect(fixture.nativeElement.querySelector('.es-list-empty')).toBeTruthy();
  });

  it('renders wizard progress with crop step active and farm step link', async () => {
    await showCrops([
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

    expect(fixture.nativeElement.querySelector('.funnel-shell-header--wizard')).toBeTruthy();
    const farmLink = fixture.nativeElement.querySelector('a.step-label-link') as HTMLAnchorElement;
    expect(farmLink?.getAttribute('href')).toBe('/entry-schedule');
    expect(fixture.nativeElement.querySelector('.compact-step.active .step-label')?.textContent?.trim()).toBe(
      'Crop',
    );
  });

  it('renders breadcrumb and selected farm summary card', async () => {
    await showCrops([
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

    const backLink = fixture.nativeElement.querySelector(
      'a.master-context-header__back',
    ) as HTMLAnchorElement;
    expect(backLink?.getAttribute('href')).toBe('/entry-schedule');
    expect(backLink?.textContent?.trim()).toBe('Entry schedule');

    const current = fixture.nativeElement.querySelector('[aria-current="page"]');
    expect(current?.textContent?.trim()).toBe('Farm A');

    const summary = fixture.nativeElement.querySelector('.enhanced-summary-card');
    expect(summary).toBeTruthy();
    expect(summary?.textContent).toContain('Selected farm');
    expect(summary?.textContent).toContain('Farm A');
  });

  it('redirects to entry-schedule with flash when farm id is invalid', async () => {
    farmIdParam = 'abc';
    const navigateSpy = vi.spyOn(router, 'navigate');

    await initComponent();

    expect(flash.show).toHaveBeenCalledWith({
      type: 'warning',
      text: 'entrySchedule.invalid_farm_id',
    });
    expect(navigateSpy).toHaveBeenCalledWith(['/entry-schedule'], { replaceUrl: true });
  });

  it('redirects to entry-schedule with flash when farm does not exist', async () => {
    farmIdParam = '999';
    const navigateSpy = vi.spyOn(router, 'navigate');

    await initComponent();

    expect(flash.show).toHaveBeenCalledWith({
      type: 'warning',
      text: 'entrySchedule.invalid_farm_id',
    });
    expect(navigateSpy).toHaveBeenCalledWith(['/entry-schedule'], { replaceUrl: true });
  });

  it('renders paved-road empty pattern when crop has no planting windows', async () => {
    await showCrops([
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
    expect(card.querySelector('.es-crop-card-empty')).toBeTruthy();
    expect(card.querySelector('.es-link-detail')).toBeTruthy();
  });

  it('renders list empty block when crops response is empty', async () => {
    await showCrops([]);

    const empty = fixture.nativeElement.querySelector('.es-list-empty') as HTMLElement;
    expect(empty).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.es-crop-grid')).toBeNull();
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

    await initComponent();

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
    const cropNames = Array.from(fixture.nativeElement.querySelectorAll('.es-crop-name')).map(
      (node: Element) => node.textContent?.trim(),
    );
    expect(cropNames).toEqual(['Tomato', 'Cucumber']);
  });

  it('distinguishes loading, error, and list empty states visually', async () => {
    const cropsSubject = new Subject<{
      farm: Farm;
      crops: EntryScheduleCropListItem[];
      prediction: Record<string, unknown>;
      meta: { has_more: boolean; next_cursor: null };
    }>();
    getEntryScheduleCrops.mockReturnValue(cropsSubject.asObservable());

    await initComponent();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.master-loading')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.error-message')).toBeNull();

    cropsSubject.next({
      farm: farms[0],
      crops: [],
      prediction: {},
      meta: { has_more: false, next_cursor: null },
    });
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.es-list-empty')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.master-loading')).toBeNull();

    getEntryScheduleCrops.mockReturnValue(throwError(() => new Error('network')));
    fixture.componentInstance.loadCrops(false);
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.error-message')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.es-list-empty')).toBeNull();
  });
});
