import { Routes } from '@angular/router';

export const entryScheduleRoutes: Routes = [
  {
    path: 'entry-schedule/crop/:cropId',
    loadComponent: () =>
      import('../components/entry-schedule/entry-schedule-detail.component').then(
        (m) => m.EntryScheduleDetailComponent
      )
  },
  {
    path: 'entry-schedule',
    loadComponent: () =>
      import('../components/entry-schedule/entry-schedule-list.component').then(
        (m) => m.EntryScheduleListComponent
      )
  }
];
