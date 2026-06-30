import { Routes } from '@angular/router';
import { authGuard } from '../guards/auth.guard';

export const workRoutes: Routes = [
  {
    path: 'work',
    loadComponent: () =>
      import('../components/work-hub/work-hub.component').then((m) => m.WorkHubComponent),
    canActivate: [authGuard]
  }
];
