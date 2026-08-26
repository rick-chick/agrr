import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { of } from 'rxjs';
import { vi } from 'vitest';
import { EntryScheduleListComponent } from './entry-schedule-list.component';
import { ENTRY_SCHEDULE_GATEWAY } from '../../usecase/entry-schedule/entry-schedule-gateway';
import type { Farm } from '../../domain/farms/farm';

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
});
