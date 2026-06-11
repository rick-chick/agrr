import { Routes } from '@angular/router';
import { coreRoutes } from './routes/core.routes';
import { mastersRoutes } from './routes/masters.routes';
import { plansRoutes } from './routes/plans.routes';
import { publicPlansRoutes } from './routes/public-plans.routes';
import { entryScheduleRoutes } from './routes/entry-schedule.routes';
import { pagesRoutes } from './routes/pages.routes';

export const routes: Routes = [
  ...coreRoutes,
  ...mastersRoutes,
  ...plansRoutes,
  ...publicPlansRoutes,
  ...entryScheduleRoutes,
  ...pagesRoutes
];
