import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { of } from 'rxjs';
import { vi } from 'vitest';
import { EntryScheduleListComponent } from './entry-schedule-list.component';
import { ENTRY_SCHEDULE_GATEWAY } from '../../usecase/entry-schedule/entry-schedule-gateway';
import type { Farm } from '../../domain/farms/farm';

describe('EntryScheduleListComponent', () => {
  let fixture: ComponentFixture<EntryScheduleListComponent>;
  let translate: TranslateService;
  let router: Router;
  let getEntryScheduleFarms: ReturnType<typeof vi.fn>;

  const farms: Farm[] = [
    { id: 1, name: 'Farm A', latitude: 35, longitude: 139, region: 'jp' },
    { id: 2, name: 'Farm B', latitude: 34, longitude: 135, region: 'jp' },
  ];

  beforeEach(async () => {
    getEntryScheduleFarms = vi.fn(() => of(farms));

    await TestBed.configureTestingModule({
      imports: [EntryScheduleListComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([
          { path: 'entry-schedule', component: EntryScheduleListComponent },
          { path: 'entry-schedule/farm/:farmId', component: EntryScheduleListComponent },
        ]),
        {
          provide: ENTRY_SCHEDULE_GATEWAY,
          useValue: {
            getEntryScheduleFarms,
            getEntryScheduleCrops: vi.fn(),
          },
        },
      ],
    }).compileComponents();

    router = TestBed.inject(Router);
    fixture = TestBed.createComponent(EntryScheduleListComponent);
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      entrySchedule: {
        title: 'Entry schedule',
        selectFarm: 'Select a farm',
        loading: 'Loading…',
        noFarms: 'No farms available',
        retry: 'Retry',
        error: 'Could not load farms',
        steps: {
          farm: 'Farm',
          crop: 'Crop',
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

  it('renders FunnelShell with farm selection cards only', async () => {
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-funnel-shell')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('app-farm-selection-cards')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('section.content-card')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.es-crop-grid')).toBeNull();
    expect(fixture.nativeElement.querySelector('.placeholder-block')).toBeNull();
  });

  it('renders wizard funnel shell with farm step active', async () => {
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const shell = fixture.nativeElement.querySelector('.funnel-shell-header--wizard');
    expect(shell).toBeTruthy();

    const activeStep = fixture.nativeElement.querySelector('.compact-step.active .step-label');
    expect(activeStep?.textContent?.trim()).toBe('Farm');
    expect(fixture.nativeElement.querySelector('a.step-label-link')).toBeNull();
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

  it('navigates to farm crops route when a farm card is selected', async () => {
    const navigateSpy = vi.spyOn(router, 'navigate');

    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const cards = fixture.nativeElement.querySelectorAll(
      '.enhanced-selection-card',
    ) as NodeListOf<HTMLElement>;
    cards[0].click();
    await fixture.whenStable();

    expect(navigateSpy).toHaveBeenCalledWith(['/entry-schedule/farm', 1]);
  });

  it('auto-navigates to farm crops route when the user has a single farm', async () => {
    getEntryScheduleFarms.mockReturnValue(of([farms[0]]));
    const navigateSpy = vi.spyOn(router, 'navigate');

    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(navigateSpy).toHaveBeenCalledWith(['/entry-schedule/farm', 1]);
    expect(fixture.nativeElement.querySelectorAll('.enhanced-selection-card').length).toBe(1);
  });
});
