import { Routes } from '@angular/router';
import { coreRoutes } from './routes/core.routes';
import { mastersRoutes } from './routes/masters.routes';
import { settingsRoutes } from './routes/settings.routes';
import { plansRoutes } from './routes/plans.routes';
import { publicPlansRoutes } from './routes/public-plans.routes';
import { entryScheduleRoutes } from './routes/entry-schedule.routes';
import { weatherRoutes } from './routes/weather.routes';
import { pagesRoutes } from './routes/pages.routes';

export const routes: Routes = [
  ...coreRoutes,
  ...mastersRoutes,
  ...settingsRoutes,
  ...plansRoutes,
  ...publicPlansRoutes,
  ...entryScheduleRoutes,
  ...weatherRoutes,
  ...pagesRoutes
];
