import { Routes } from '@angular/router';
import { authGuard } from '../guards/auth.guard';

export const plansRoutes: Routes = [
  {
    path: 'plans',
    loadComponent: () =>
      import('../components/plans/plan-list.component').then((m) => m.PlanListComponent),
    canActivate: [authGuard]
  },
  {
    path: 'plans/new',
    loadComponent: () =>
      import('../components/plans/plan-new.component').then((m) => m.PlanNewComponent),
    canActivate: [authGuard]
  },
  {
    path: 'plans/:id',
    loadComponent: () =>
      import('../components/plans/plan-detail.component').then((m) => m.PlanDetailComponent),
    canActivate: [authGuard]
  },
  {
    path: 'plans/:id/optimizing',
    loadComponent: () =>
      import('../components/plans/plan-optimizing.component').then((m) => m.PlanOptimizingComponent),
    canActivate: [authGuard]
  },
  {
    path: 'plans/:id/task_schedule',
    loadComponent: () =>
      import('../components/plans/plan-task-schedule.component').then(
        (m) => m.PlanTaskScheduleComponent
      ),
    canActivate: [authGuard]
  },
  {
    path: 'plans/:id/work',
    loadComponent: () =>
      import('../components/plans/plan-work.component').then((m) => m.PlanWorkComponent),
    canActivate: [authGuard]
  },
  {
    path: 'plans/:id/work_records',
    loadComponent: () =>
      import('../components/plans/plan-work-records.component').then(
        (m) => m.PlanWorkRecordsComponent
      ),
    canActivate: [authGuard]
  }
];
