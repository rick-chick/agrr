import { Routes } from '@angular/router';
import { authGuard } from '../guards/auth.guard';

export const weatherRoutes: Routes = [
  {
    path: 'weather',
    loadComponent: () =>
      import('../components/weather/weather-page.component').then((m) => m.WeatherPageComponent),
    canActivate: [authGuard]
  }
];
