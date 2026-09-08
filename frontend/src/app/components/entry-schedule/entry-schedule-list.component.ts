import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { EntryScheduleListView, EntryScheduleListViewState } from './entry-schedule-list.view';
import { LoadEntryScheduleFarmsUseCase } from '../../usecase/entry-schedule/load-entry-schedule-farms.usecase';
import {
  EntryScheduleListPresenter,
  ENTRY_SCHEDULE_LIST_PROVIDERS
} from '../../adapters/entry-schedule/entry-schedule-list.providers';
import { Farm } from '../../domain/farms/farm';
import { detectBrowserRegion } from '../../core/browser-region';
import { FarmSelectionCardsComponent } from '../shared/farm-selection-cards/farm-selection-cards.component';
import { FunnelShellComponent } from '../shared/shells/funnel-shell.component';
import { EntryScheduleWizardProgressComponent } from './entry-schedule-wizard-progress.component';
import { displayEntryScheduleFarmName } from './entry-schedule-farm-display';

const initialControl: EntryScheduleListViewState = {
  farmsLoading: true,
  farmsError: null,
  farms: []
};

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
  providers: [...ENTRY_SCHEDULE_LIST_PROVIDERS],
  template: `
    <div class="page-main public-plans-wrapper">
      <div class="free-plans-container">
        <app-funnel-shell
          variant="wizard"
          titleKey="entrySchedule.title"
          titleIcon="📅"
        >
          <p class="visually-hidden">{{ 'pages.entry_schedule.description' | translate }}</p>
          <app-entry-schedule-wizard-progress ngProjectAs="[wizardProgress]" activeStep="farm" />
          <section class="content-card" aria-labelledby="entry-schedule-heading">
            <h2 id="entry-schedule-heading" class="visually-hidden">
              {{ 'entrySchedule.selectFarm' | translate }}
            </h2>
            @if (control.farmsLoading) {
              <p class="muted master-loading">{{ 'entrySchedule.loading' | translate }}</p>
            } @else if (control.farmsError) {
              <p class="error-message">{{ control.farmsError | translate }}</p>
              <button type="button" class="btn btn-secondary mt-2" (click)="retryFarms()">
                {{ 'entrySchedule.retry' | translate }}
              </button>
            } @else if (control.farms.length === 0) {
              <p class="muted">{{ 'entrySchedule.noFarms' | translate }}</p>
            } @else {
              <app-farm-selection-cards
                [farms]="control.farms"
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
export class EntryScheduleListComponent implements EntryScheduleListView, OnInit {
  private readonly useCase = inject(LoadEntryScheduleFarmsUseCase);
  private readonly presenter = inject(EntryScheduleListPresenter);
  private readonly router = inject(Router);
  private readonly translate = inject(TranslateService);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: EntryScheduleListViewState = initialControl;
  get control(): EntryScheduleListViewState {
    return this._control;
  }
  set control(value: EntryScheduleListViewState) {
    this._control = value;
    this.cdr.detectChanges();
    if (!value.farmsLoading && !value.farmsError && value.farms.length === 1) {
      void this.router.navigate(['/entry-schedule/farm', value.farms[0].id]);
    }
  }

  displayFarmName(farm: Farm): string {
    return displayEntryScheduleFarmName(farm, this.translate);
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.loadFarmsList();
  }

  private loadFarmsList(): void {
    const region = detectBrowserRegion();
    this.control = {
      ...this.control,
      farmsError: null,
      farmsLoading: true,
      farms: []
    };
    this.useCase.execute({ region });
  }

  retryFarms(): void {
    this.loadFarmsList();
  }

  selectFarm(farm: Farm): void {
    void this.router.navigate(['/entry-schedule/farm', farm.id]);
  }
}
