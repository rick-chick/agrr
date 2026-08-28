import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { catchError, map, of } from 'rxjs';
import type { PlanSummary } from '../domain/plans/plan-summary';
import { ApiService } from '../services/api.service';

export const onboardingGuard: CanActivateFn = () => {
  const api = inject(ApiService);
  const router = inject(Router);

  return api.get<PlanSummary[]>('/api/v1/plans').pipe(
    map((plans) => (plans.length > 0 ? router.createUrlTree(['/plans']) : true)),
    catchError(() => of(router.createUrlTree(['/plans'])))
  );
};
