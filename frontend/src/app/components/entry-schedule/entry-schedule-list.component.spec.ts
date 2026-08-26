import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { of } from 'rxjs';
import { vi } from 'vitest';
import { EntryScheduleListComponent } from './entry-schedule-list.component';
import { ENTRY_SCHEDULE_GATEWAY } from '../../usecase/entry-schedule/entry-schedule-gateway';

describe('EntryScheduleListComponent', () => {
  let fixture: ComponentFixture<EntryScheduleListComponent>;
  let getCrops: ReturnType<typeof vi.fn>;

  beforeEach(async () => {
    getCrops = vi.fn(() =>
      of({
        farm: { id: 1, name: 'Farm A', latitude: 0, longitude: 0, region: 'jp' },
        prediction: { chart_calendar_year: 2026 },
        meta: { has_more: false, next_cursor: null },
        crops: [
          {
            id: 10,
            name: 'Crop A',
            eligible: false,
            sowing_summary: null,
            transplant_summary: null,
            schedule_flow_summary: '—',
            reason_summary: 'Too cold',
          },
        ],
      }),
    );

    await TestBed.configureTestingModule({
      imports: [EntryScheduleListComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        {
          provide: ENTRY_SCHEDULE_GATEWAY,
          useValue: {
            getEntryScheduleFarms: vi.fn(() =>
              of([{ id: 1, name: 'Farm A', latitude: 0, longitude: 0, region: 'jp' }]),
            ),
            getEntryScheduleCrops: getCrops,
          },
        },
      ],
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation('en', {
      'entrySchedule.title': 'Entry schedule',
      'pages.entry_schedule.description': 'Description',
      'entrySchedule.selectFarm': 'Select farm',
      'entrySchedule.loading': 'Loading',
      'entrySchedule.allIneligibleTitle': 'No in-season crops',
      'entrySchedule.allIneligibleBody': 'No windows',
      'entrySchedule.allIneligibleTryOtherFarm': 'Try another farm',
      'entrySchedule.allIneligiblePublicPlanCta': 'Create plan',
      'entrySchedule.listDisclaimer': 'Disclaimer',
    });

    fixture = TestBed.createComponent(EntryScheduleListComponent);
  });

  it('mounts FunnelShell and farm selection cards', async () => {
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-funnel-shell')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('[data-testid="farm-selection-cards"]')).toBeTruthy();
  });

  it('shows single empty block when all crops are ineligible without windows', async () => {
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
    await vi.waitFor(() => {
      expect(fixture.nativeElement.querySelector('[data-testid="entry-schedule-all-ineligible"]')).toBeTruthy();
    });

    expect(fixture.nativeElement.querySelector('[data-testid="entry-schedule-crop-grid"]')).toBeNull();
    expect(fixture.nativeElement.querySelectorAll('.es-crop-card').length).toBe(0);
  });
});
