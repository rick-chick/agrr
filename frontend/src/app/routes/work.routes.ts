import { Routes } from '@angular/router';
import { authGuard } from '../guards/auth.guard';

export const workRoutes: Routes = [
  {
    path: 'work/variance',
    loadComponent: () =>
      import('../components/work-variance/work-variance.component').then((m) => m.WorkVarianceComponent),
    canActivate: [authGuard]
  },
  {
    path: 'work',
    loadComponent: () =>
      import('../components/work-hub/work-hub.component').then((m) => m.WorkHubComponent),
    canActivate: [authGuard]
  }
];
