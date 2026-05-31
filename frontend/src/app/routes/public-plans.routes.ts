import { Routes } from '@angular/router';

export const publicPlansRoutes: Routes = [
  {
    path: 'public-plans/new',
    loadComponent: () =>
      import('../components/public-plans/public-plan-create.component').then(
        (m) => m.PublicPlanCreateComponent
      )
  },
  {
    path: 'public-plans/select-farm-size',
    redirectTo: '/public-plans/new',
    pathMatch: 'full'
  },
  {
    path: 'public-plans/select-crop',
    loadComponent: () =>
      import('../components/public-plans/public-plan-select-crop.component').then(
        (m) => m.PublicPlanSelectCropComponent
      )
  },
  {
    path: 'public-plans/optimizing',
    loadComponent: () =>
      import('../components/public-plans/public-plan-optimizing.component').then(
        (m) => m.PublicPlanOptimizingComponent
      )
  },
  {
    path: 'public-plans/results',
    loadComponent: () =>
      import('../components/public-plans/public-plan-results.component').then(
        (m) => m.PublicPlanResultsComponent
      )
  }
];
