import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { catchError, of, timeout } from 'rxjs';
import { ENTRY_SCHEDULE_GATEWAY } from '../../usecase/entry-schedule/entry-schedule-gateway';
import { Farm } from '../../domain/farms/farm';
import { detectBrowserRegion } from '../../core/browser-region';
import { FarmSelectionCardsComponent } from '../shared/farm-selection-cards/farm-selection-cards.component';
import { FunnelShellComponent } from '../shared/shells/funnel-shell.component';
import { EntryScheduleWizardProgressComponent } from './entry-schedule-wizard-progress.component';
import { displayEntryScheduleFarmName } from './entry-schedule-farm-display';

const ENTRY_SCHEDULE_HTTP_TIMEOUT_MS = 25_000;

@Component({
  selector: 'app-entry-schedule-list',
  standalone: true,
  imports: [
    CommonModule,
    TranslateModule,
    FarmSelectionCardsComponent,
    FunnelShellComponent,
    EntryScheduleWizardProgressComponent,
  ],
  template: `
    <div class="page-main public-plans-wrapper">
      <div class="free-plans-container">
        <app-funnel-shell
          variant="wizard"
          titleKey="entrySchedule.title"
          descriptionKey="pages.entry_schedule.description"
          titleIcon="📅"
        >
          <app-entry-schedule-wizard-progress activeStep="farm" />
          <section class="content-card" aria-labelledby="entry-schedule-heading">
            <h2 id="entry-schedule-heading" class="visually-hidden">
              {{ 'entrySchedule.selectFarm' | translate }}
            </h2>
            @if (farmsLoading()) {
              <p class="muted master-loading">{{ 'entrySchedule.loading' | translate }}</p>
            } @else if (farmsError()) {
              <p class="error-message">{{ farmsError()! | translate }}</p>
              <button type="button" class="btn btn-secondary mt-2" (click)="retryFarms()">
                {{ 'entrySchedule.retry' | translate }}
              </button>
            } @else if (farms().length === 0) {
              <p class="muted">{{ 'entrySchedule.noFarms' | translate }}</p>
            } @else {
              <app-farm-selection-cards
                [farms]="farms()"
                [selectedFarmId]="null"
                [heading]="'entrySchedule.selectFarm' | translate"
                headingId="farm-heading"
                [farmLabel]="displayFarmName.bind(this)"
                (farmSelect)="selectFarm($event)"
              />
            }
          </section>
        </app-funnel-shell>
      </div>
    </div>
  `,
  styleUrls: ['../shared/shells/funnel-shell.component.css', '../public-plans/public-plan.component.css'],
  styles: [
    `
      .visually-hidden {
        position: absolute;
        width: 1px;
        height: 1px;
        padding: 0;
        margin: -1px;
        overflow: hidden;
        clip: rect(0, 0, 0, 0);
        border: 0;
      }
    `
  ]
})
export class EntryScheduleListComponent implements OnInit {
  private readonly gateway = inject(ENTRY_SCHEDULE_GATEWAY);
  private readonly router = inject(Router);
  private readonly translate = inject(TranslateService);

  readonly farms = signal<Farm[]>([]);
  readonly farmsLoading = signal(true);
  readonly farmsError = signal<string | null>(null);

  displayFarmName(farm: Farm): string {
    return displayEntryScheduleFarmName(farm, this.translate);
  }

  ngOnInit(): void {
    this.loadFarmsList();
  }

  private loadFarmsList(): void {
    const region = detectBrowserRegion();
    this.farmsError.set(null);
    this.farmsLoading.set(true);
    this.gateway
      .getEntryScheduleFarms(region)
      .pipe(
        timeout(ENTRY_SCHEDULE_HTTP_TIMEOUT_MS),
        catchError((err: unknown) => {
          const name = err && typeof err === 'object' && 'name' in err ? String((err as { name: string }).name) : '';
          if (name === 'TimeoutError') {
            this.farmsError.set('entrySchedule.timeout');
          } else {
            this.farmsError.set('entrySchedule.error');
          }
          return of([] as Farm[]);
        })
      )
      .subscribe((rows) => {
        this.farms.set(rows);
        this.farmsLoading.set(false);
        if (rows.length === 1) {
          void this.router.navigate(['/entry-schedule/farm', rows[0].id]);
        }
      });
  }

  retryFarms(): void {
    this.farmsLoading.set(true);
    this.loadFarmsList();
  }

  selectFarm(farm: Farm): void {
    void this.router.navigate(['/entry-schedule/farm', farm.id]);
  }
}
