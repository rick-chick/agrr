import { Routes } from '@angular/router';
import { authGuard } from '../guards/auth.guard';

export const settingsRoutes: Routes = [
  {
    path: 'api-keys',
    loadComponent: () =>
      import('../components/settings/api-key/api-key.component').then((m) => m.ApiKeyComponent),
    canActivate: [authGuard]
  }
];
