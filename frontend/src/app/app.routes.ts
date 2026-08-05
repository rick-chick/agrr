import { Routes } from '@angular/router';
import { coreRoutes } from './routes/core.routes';
import { mastersRoutes } from './routes/masters.routes';
import { plansRoutes } from './routes/plans.routes';
import { publicPlansRoutes } from './routes/public-plans.routes';
import { entryScheduleRoutes } from './routes/entry-schedule.routes';
import { workRoutes } from './routes/work.routes';
import { pagesRoutes } from './routes/pages.routes';
import { enPublicRoutes } from './routes/en-public.routes';

export const routes: Routes = [
  ...enPublicRoutes,
  ...coreRoutes,
  ...mastersRoutes,
  ...plansRoutes,
  ...workRoutes,
  ...publicPlansRoutes,
  ...entryScheduleRoutes,
  ...pagesRoutes
];
