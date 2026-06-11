import { inject } from '@angular/core';
import { CanActivateFn, Router, RouterStateSnapshot } from '@angular/router';
import { map } from 'rxjs';
import {
  locationLikeFromRouterUrl,
  loginReturnQueryForLocation
} from '../components/auth/login/login-auth-urls';
import { AuthService } from '../services/auth.service';

export const authGuard: CanActivateFn = (_route, state: RouterStateSnapshot) => {
  const authService = inject(AuthService);
  const router = inject(Router);

  if (authService.user()) {
    return true;
  }

  return authService.loadCurrentUser().pipe(
    map((user) => {
      if (user) {
        return true;
      }
      const queryParams =
        typeof window !== 'undefined'
          ? loginReturnQueryForLocation(
              locationLikeFromRouterUrl(state.url, window.location.origin)
            )
          : {};
      return router.createUrlTree(['/login'], { queryParams });
    })
  );
};
