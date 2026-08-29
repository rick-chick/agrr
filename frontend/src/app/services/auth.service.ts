import { Injectable, signal, inject } from '@angular/core';
import { catchError, map, of, tap, Observable } from 'rxjs';
import { ApiService, CurrentUser } from './api.service';
import { ApiKeyService } from './api-key.service';
import { detectBrowserRegion } from '../core/browser-region';
import {
  isAuthMeSessionUnavailableError,
  isAuthMeUnauthenticatedError
} from '../core/auth/auth-me-error';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly userSignal = signal<CurrentUser | null>(null);
  private readonly loadingSignal = signal(false);
  private readonly sessionUnavailableSignal = signal(false);
  private loaded = false;

  private readonly api = inject(ApiService);
  private readonly apiKeyService = inject(ApiKeyService);

  user() {
    return this.userSignal();
  }

  loading() {
    return this.loadingSignal();
  }

  sessionUnavailable() {
    return this.sessionUnavailableSignal();
  }

  loadCurrentUser(): Observable<CurrentUser | null> {
    if (this.loaded) {
      return of(this.userSignal());
    }

    this.loadingSignal.set(true);
    return this.api.getCurrentUser().pipe(
      map((response) => response.user),
      tap((user) => {
        this.apiKeyService.clearApiKey();
        user.region = user.region ?? detectBrowserRegion();
        this.userSignal.set(user);
        this.sessionUnavailableSignal.set(false);
        this.loaded = true;
        this.loadingSignal.set(false);
      }),
      catchError((error: unknown) => {
        if (isAuthMeSessionUnavailableError(error)) {
          this.sessionUnavailableSignal.set(true);
        } else if (isAuthMeUnauthenticatedError(error)) {
          this.userSignal.set(null);
          this.sessionUnavailableSignal.set(false);
        } else {
          this.userSignal.set(null);
          this.sessionUnavailableSignal.set(false);
        }
        this.loaded = true;
        this.loadingSignal.set(false);
        return of(null);
      })
    );
  }

  retryLoadCurrentUser(): Observable<CurrentUser | null> {
    this.loaded = false;
    this.sessionUnavailableSignal.set(false);
    return this.loadCurrentUser();
  }

  logout() {
    return this.api.logout().pipe(
      tap(() => {
        this.apiKeyService.clearApiKey();
        this.userSignal.set(null);
        this.sessionUnavailableSignal.set(false);
      })
    );
  }
}
